# Makefile - Sık kullanılan komutlar
#
# Kullanım: make up, make run, make test

.PHONY: up down run migrate seed

# Docker altyapısını başlat (PostgreSQL, RabbitMQ, MinIO)
up:
	docker compose up -d

# Durdur
down:
	docker compose down

# Uygulamayı çalıştır (Go kurulu olmalı)
run:
	go run ./cmd/server

# Bağımlılıkları indir
deps:
	go mod tidy
	go mod download

# Tümünü başlat: önce up, sonra run
# Not: PostgreSQL'in hazır olması için birkaç saniye bekleyin
dev: up
	@echo "5 saniye bekleniyor (PostgreSQL hazır olsun)..."
	@sleep 5
	go run ./cmd/server
