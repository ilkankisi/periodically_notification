// internal/storage/handler.go
//
// Görsel yükleme endpoint'i. JWT zorunlu - sadece giriş yapmış kullanıcılar yükleyebilir.

package storage

import (
	"net/http"
	"path/filepath"
	"strings"

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
