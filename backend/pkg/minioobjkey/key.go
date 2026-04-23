// Package minioobjkey — MinIO public URL içinden nesne anahtarı çıkarma (url.Parse ';' kırpmasından kaçınır).
package minioobjkey

import (
	"net/url"
	"strings"
)

// PathSegmentsUnsafe yalnızca gerçek . ve .. path segmentlerini işaretler (dosya adındaki "..jpeg" güvenli).
func PathSegmentsUnsafe(objectKey string) bool {
	for _, seg := range strings.Split(objectKey, "/") {
		if seg == ".." || seg == "." {
			return true
		}
	}
	return false
}

// AfterBucket rawURL içinde "/{bucket}/" sonrası nesne anahtarını döner.
func AfterBucket(rawURL, bucket string) (string, bool) {
	bucket = strings.TrimSpace(bucket)
	if bucket == "" || rawURL == "" {
		return "", false
	}
	needle := "/" + bucket + "/"
	idx := strings.Index(rawURL, needle)
	if idx < 0 {
		return "", false
	}
	key := rawURL[idx+len(needle):]
	if q := strings.Index(key, "?"); q >= 0 {
		key = key[:q]
	}
	if h := strings.Index(key, "#"); h >= 0 {
		key = key[:h]
	}
	key = strings.TrimSpace(key)
	if key == "" || PathSegmentsUnsafe(key) {
		return "", false
	}
	dec, err := url.PathUnescape(key)
	if err == nil && dec != "" {
		key = dec
	}
	return key, true
}
