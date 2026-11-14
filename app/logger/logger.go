package logger

import (
	"log"
	"os"
)

var (
	infoLogger  = log.New(os.Stdout, "[INFO] ", log.Ldate|log.Ltime|log.LUTC)
	warnLogger  = log.New(os.Stdout, "[WARN] ", log.Ldate|log.Ltime|log.LUTC)
	errorLogger = log.New(os.Stderr, "[ERROR] ", log.Ldate|log.Ltime|log.LUTC)
)

func Info(msg string) {
	infoLogger.Println(msg)
}

func Infof(format string, v ...interface{}) {
	infoLogger.Printf(format, v...)
}

func Warn(msg string) {
	warnLogger.Println(msg)
}

func Warnf(format string, v ...interface{}) {
	warnLogger.Printf(format, v...)
}

func Error(msg string) {
	errorLogger.Println(msg)
}

func Errorf(format string, v ...interface{}) {
	errorLogger.Printf(format, v...)
}

func Fatalf(format string, v ...interface{}) {
	errorLogger.Fatalf(format, v...)
}
