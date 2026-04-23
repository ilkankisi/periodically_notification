// internal/storage/handler.go
//
// Görsel yükleme endpoint'i. JWT zorunlu - sadece giriş yapmış kullanıcılar yükleyebilir.

package storage

import (
	"io"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"

	"periodically/backend/pkg/minioobjkey"
	miniostorage "periodically/backend/pkg/storage"

	"github.com/gin-gonic/gin"
)

var allowedExtensions = map[string]bool{
	".jpg": true, ".jpeg": true, ".png": true, ".gif": true, ".webp": true,
}

const maxSize = 5 << 20 // 5 MB

// Handler görsel yükleme işlemleri.
type Handler struct {
	Storage *miniostorage.Client
}

// Upload multipart form "file" kabul eder, MinIO'ya yükler, URL döner.
func (h *Handler) Upload(c *gin.Context) {
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Dosya gerekli (form field: file)"})
		return
	}

	ext := strings.ToLower(filepath.Ext(file.Filename))
	if !allowedExtensions[ext] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Sadece görsel dosyaları (.jpg, .jpeg, .png, .gif, .webp) yüklenebilir"})
		return
	}

	if file.Size > maxSize {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Dosya boyutu 5 MB'dan küçük olmalı"})
		return
	}

	opened, err := file.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Dosya açılamadı"})
		return
	}
	defer opened.Close()

	contentType := file.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	url, err := h.Storage.Upload(c.Request.Context(), opened, contentType, file.Filename)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Yükleme başarısız"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"url":  url,
		"size": file.Size,
		"name": file.Filename,
	})
}

// ServeMedia MinIO nesnesini backend üzerinden stream eder: GET /api/media/{bucket}/{objectKey...}
// Yalnızca yapılandırılmış bucket kabul edilir; path traversal reddedilir.
func (h *Handler) ServeMedia(c *gin.Context) {
	rel := strings.TrimPrefix(c.Param("filepath"), "/")
	if rel == "" {
		c.Status(http.StatusNotFound)
		return
	}
	parts := strings.Split(rel, "/")
	if len(parts) < 2 {
		c.Status(http.StatusNotFound)
		return
	}
	bucket := parts[0]
	if bucket != h.Storage.BucketName() {
		c.Status(http.StatusNotFound)
		return
	}
	objectKey := strings.Join(parts[1:], "/")
	if objectKey == "" || minioobjkey.PathSegmentsUnsafe(objectKey) {
		c.Status(http.StatusBadRequest)
		return
	}

	obj, err := h.Storage.GetObject(c.Request.Context(), objectKey)
	if err != nil {
		c.Status(http.StatusNotFound)
		return
	}
	defer obj.Close()

	stat, err := obj.Stat()
	if err != nil {
		c.Status(http.StatusNotFound)
		return
	}

	ct := stat.ContentType
	if ct == "" {
		ct = "application/octet-stream"
	}
	c.Header("Content-Type", ct)
	c.Header("Cache-Control", "public, max-age=86400")
	if stat.Size > 0 {
		c.Header("Content-Length", strconv.FormatInt(stat.Size, 10))
	}

	if _, err := io.Copy(c.Writer, obj); err != nil {
		if !c.Writer.Written() {
			c.Status(http.StatusInternalServerError)
		}
		return
	}
}
