// Package mediaurl — görsel URL'lerini API medya proxy'si ile uyumlu hale getirir.
package mediaurl

import (
	"net/url"
	"strings"

	"periodically/backend/pkg/minioobjkey"
)

// RewriteMinIOToProxy .../bucket/objectKey biçimindeki URL'yi GET /api/media/... adresine çevirir.
// apiPublic boşsa raw aynen döner.
func RewriteMinIOToProxy(apiPublic, bucket, raw string) string {
	apiPublic = strings.TrimSpace(apiPublic)
	bucket = strings.TrimSpace(bucket)
	if apiPublic == "" || bucket == "" || raw == "" {
		return raw
	}
	objKey, ok := minioobjkey.AfterBucket(raw, bucket)
	if !ok {
		return raw
	}
	base, err := url.Parse(strings.TrimSpace(apiPublic))
	if err != nil {
		return raw
	}
	var b strings.Builder
	b.WriteString(strings.TrimSuffix(base.Path, "/"))
	b.WriteString("/api/media/")
	b.WriteString(url.PathEscape(bucket))
	for _, seg := range strings.Split(objKey, "/") {
		if seg == "" {
			continue
		}
		b.WriteByte('/')
		b.WriteString(url.PathEscape(seg))
	}
	base.Path = b.String()
	base.RawPath = ""
	return base.String()
}
