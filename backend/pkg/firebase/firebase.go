package firebase

import (
	"context"
	"log"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"google.golang.org/api/option"
)

var authClient *auth.Client

// Init Firebase Admin Auth (sadece POST /api/auth/token vb. için).
// projectID boşsa Auth kapalıdır.
func Init(ctx context.Context, projectID, authCredentialsPath string) error {
	if projectID == "" {
		log.Println("Firebase Auth devre dışı (FIREBASE_PROJECT_ID boş)")
		return nil
	}
	opts := []option.ClientOption{}
	if authCredentialsPath != "" {
		opts = append(opts, option.WithCredentialsFile(authCredentialsPath))
	} else {
		log.Println("Firebase Auth: FIREBASE_AUTH_CREDENTIALS_PATH boş; Auth başlatılmayacak")
		return nil
	}
	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID}, opts...)
	if err != nil {
		return err
	}
	var errAuth error
	authClient, errAuth = app.Auth(ctx)
	if errAuth != nil {
		return errAuth
	}
	log.Println("Firebase Admin SDK (Auth) başlatıldı")
	return nil
}

// VerifyIDToken Firebase ID token doğrular, uid + email döner.
func VerifyIDToken(ctx context.Context, idToken string) (uid, email, name, photoURL string, err error) {
	if authClient == nil {
		return "", "", "", "", nil
	}
	token, err := authClient.VerifyIDToken(ctx, idToken)
	if err != nil {
		return "", "", "", "", err
	}
	uid = token.UID
	if claims, ok := token.Claims["email"]; ok {
		email, _ = claims.(string)
	}
	if claims, ok := token.Claims["name"]; ok {
		name, _ = claims.(string)
	}
	if claims, ok := token.Claims["picture"]; ok {
		photoURL, _ = claims.(string)
	}
	return uid, email, name, photoURL, nil
}
