// pkg/storage/minio.go
//
// MinIO (S3-uyumlu) client. Görsel yükleme ve public URL oluşturma.
// NEDEN pkg?: Başka servislerde de kullanılabilir; auth'dan bağımsız.

package storage

import (
	"context"
	"fmt"
	"io"
	"log"
	"mime"
	"net/url"
	"path"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type Client struct {
	client     *minio.Client
	bucket     string
	publicURL  string
}

// New MinIO client oluşturur. Başlangıçta bucket yoksa oluşturur ve public yapar.
func New(endpoint, accessKey, secretKey, bucket, publicURL string, useSSL bool) (*Client, error) {
	creds := credentials.NewStaticV4(accessKey, secretKey, "")
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  creds,
		Secure: useSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("minio client: %w", err)
	}

	s := &Client{client: client, bucket: bucket, publicURL: strings.TrimSuffix(publicURL, "/")}
	if err := s.ensureBucket(context.Background()); err != nil {
		return nil, err
	}
	return s, nil
}

// ensureBucket bucket yoksa oluşturur ve public read policy set eder.
func (s *Client) ensureBucket(ctx context.Context) error {
	exists, err := s.client.BucketExists(ctx, s.bucket)
	if err != nil {
		return fmt.Errorf("bucket kontrolü: %w", err)
	}
	if exists {
		return nil
	}
	if err := s.client.MakeBucket(ctx, s.bucket, minio.MakeBucketOptions{}); err != nil {
		return fmt.Errorf("bucket oluşturma: %w", err)
	}
	// Public read - herkes görselleri okuyabilir (örn. Flutter'da Image.network)
	policy := fmt.Sprintf(`{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":["*"]},"Action":["s3:GetObject"],"Resource":["arn:aws:s3:::%s/*"]}]}`, s.bucket)
	if err := s.client.SetBucketPolicy(ctx, s.bucket, policy); err != nil {
		log.Printf("Uyarı: bucket policy set edilemedi (görseller public olmayabilir): %v", err)
	}
	log.Printf("MinIO bucket: %s", s.bucket)
	return nil
}

// Upload dosyayı yükler, public URL döner.
// objectName: motivations/uuid-originalname.ext formatında.
func (s *Client) Upload(ctx context.Context, r io.Reader, contentType string, originalFilename string) (string, error) {
	ext := path.Ext(originalFilename)
	if ext == "" {
		ext = ".bin"
	}
	objectName := fmt.Sprintf("%s%s", uuid.New().String(), ext)

	_, err := s.client.PutObject(ctx, s.bucket, objectName, r, -1, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", fmt.Errorf("upload: %w", err)
	}

	// Public URL: http://localhost:9000/motivations/uuid.ext
	url := fmt.Sprintf("%s/%s/%s", s.publicURL, s.bucket, objectName)
	return url, nil
}

// PresignedURL geçici indirme linki (opsiyonel, public bucket varsa gerekmez).
func (s *Client) PresignedURL(ctx context.Context, objectName string, expiry time.Duration) (string, error) {
	u, err := s.client.PresignedGetObject(ctx, s.bucket, objectName, expiry, nil)
	if err != nil {
		return "", err
	}
	return u.String(), nil
}

// ObjectPublicURL bucket + object key için path segmentleri encode edilmiş public URL (Flutter Image.network ile uyumlu).
func (s *Client) ObjectPublicURL(objectKey string) string {
	return buildObjectPublicURL(s.publicURL, s.bucket, objectKey)
}

// PutLocalFile yerel dosyayı verilen object key ile yükler (örn. motivasyon_gorselleri_pexels/foo.jpg).
func (s *Client) PutLocalFile(ctx context.Context, localPath, objectKey string) error {
	ct := mime.TypeByExtension(path.Ext(localPath))
	if ct == "" {
		ct = "application/octet-stream"
	}
	_, err := s.client.FPutObject(ctx, s.bucket, objectKey, localPath, minio.PutObjectOptions{
		ContentType: ct,
	})
	return err
}

func buildObjectPublicURL(base, bucket, objectKey string) string {
	base = strings.TrimSuffix(base, "/")
	var parts []string
	for _, p := range strings.Split(objectKey, "/") {
		if p == "" {
			continue
		}
		parts = append(parts, url.PathEscape(p))
	}
	encoded := strings.Join(parts, "/")
	return fmt.Sprintf("%s/%s/%s", base, bucket, encoded)
}
