package server

import (
	"net/http"

	"periodically/backend/internal/account"
	"periodically/backend/internal/actions"
	"periodically/backend/internal/appnotifs"
	"periodically/backend/internal/auth"
	"periodically/backend/internal/blocks"
	"periodically/backend/internal/comments"
	"periodically/backend/internal/content"
	"periodically/backend/internal/dailysend"
	"periodically/backend/internal/gamification"
	"periodically/backend/internal/push"
	"periodically/backend/internal/reports"
	"periodically/backend/internal/storage"

	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"
)

// Setup route'ları kurar.
func Setup(r *gin.Engine, contentRepo *content.Repository, authRepo *auth.Repository, actionsRepo *actions.Repository, gamificationRepo *gamification.Repository, appNotifsRepo *appnotifs.Repository, storageHandler *storage.Handler, db *sqlx.DB, jwtSecret string, googleOAuthAudiences, appleOAuthAudiences []string, apnsRegister *push.Handler, dailySend *dailysend.Handler) {
	contentHandlers := &ContentHandlers{Repo: contentRepo}
	authHandlers := &auth.Handler{
		Repo:                 authRepo,
		JWTSecret:            jwtSecret,
		GoogleOAuthAudiences: googleOAuthAudiences,
		AppleOAuthAudiences:  appleOAuthAudiences,
	}
	actionsHandlers := &actions.Handler{Repo: actionsRepo, Gamify: gamificationRepo}
	reportsHandlers := reports.NewHandler(db)
	blocksHandlers := blocks.NewHandler(db, authRepo)
	accountHandlers := account.NewHandler(authRepo)
	commentsHandlers := &comments.Handler{Repo: comments.NewRepository(db), Gamify: gamificationRepo, AppNotifs: appNotifsRepo}
	gamificationHandlers := &gamification.Handler{Repo: gamificationRepo}
	appNotifsHandlers := &appnotifs.Handler{Repo: appNotifsRepo}

	api := r.Group("/api")
	{
		api.GET("/health", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "periodically-backend"})
		})
		api.GET("/daily-items", contentHandlers.ListDailyItems)
		api.GET("/daily-items/:id", contentHandlers.GetDailyItem)
		if apnsRegister != nil {
			api.POST("/push/apns-token", apnsRegister.PostApnsToken)
		}
		if dailySend != nil {
			api.POST("/admin/daily-send", dailySend.PostAdminDailySend)
		}
		api.POST("/auth/register", authHandlers.Register)
		api.POST("/auth/login", authHandlers.Login)
		api.POST("/auth/token", authHandlers.Token)
		if len(authHandlers.GoogleOAuthAudiences) > 0 {
			api.POST("/auth/oauth/google", authHandlers.OAuthGoogle)
		}
		if len(authHandlers.AppleOAuthAudiences) > 0 {
			api.POST("/auth/oauth/apple", authHandlers.OAuthApple)
		}
		api.GET("/me", auth.RequireAuth(jwtSecret), authHandlers.Me)
		api.POST("/storage/upload", auth.RequireAuth(jwtSecret), storageHandler.Upload)

		// Yorum listesi: giriş zorunlu değil; token varsa myReaction dolar.
		api.GET("/v1/comments", auth.OptionalAuth(jwtSecret), commentsHandlers.List)

		v1 := api.Group("/v1")
		v1.Use(auth.RequireAuth(jwtSecret))
		{
			v1.POST("/comments", commentsHandlers.Create)
			v1.POST("/comments/:id/reaction", commentsHandlers.PostReaction)
			v1.POST("/actions", actionsHandlers.Create)
			v1.GET("/actions/me", actionsHandlers.ListMine)
			v1.GET("/actions/for-quote", actionsHandlers.ForQuote)
			v1.GET("/actions/daily", actionsHandlers.Daily)
			v1.GET("/progress", actionsHandlers.Progress)
			v1.GET("/gamification", gamificationHandlers.GetMe)
			v1.GET("/notifications", appNotifsHandlers.List)
			v1.POST("/notifications/read-all", appNotifsHandlers.MarkAllRead)
			if apnsRegister != nil {
				v1.POST("/push/apns-token", apnsRegister.PostApnsTokenForUser)
				v1.POST("/push/apns-token/disassociate", apnsRegister.PostApnsTokenDisassociate)
			}
			v1.POST("/reports", reportsHandlers.Create)
			v1.POST("/blocks", blocksHandlers.Create)
			v1.DELETE("/blocks/:userId", blocksHandlers.Delete)
			v1.DELETE("/account", accountHandlers.Delete)
		}
	}
}

