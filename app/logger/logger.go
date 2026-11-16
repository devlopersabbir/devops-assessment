package logger

import (
	"encoding/json"
	"fmt"
	"os"
	"time"
)

type LogEntry struct {
	Timestamp string `json:"timestamp"`
	Level     string `json:"level"`
	Message   string `json:"message"`
}

func output(level, msg string) {
	entry := LogEntry{
		Timestamp: time.Now().UTC().Format(time.RFC3339Nano),
		Level:     level,
		Message:   msg,
	}
	data, err := json.Marshal(entry)
	if err != nil {
		_, _ = fmt.Fprintf(os.Stderr, "{\"level\":\"ERROR\",\"message\":\"failed to marshal log: %v\"}\n", err)
		return
	}
	if level == "ERROR" {
		_, _ = fmt.Fprintln(os.Stderr, string(data))
	} else {
		_, _ = fmt.Fprintln(os.Stdout, string(data))
	}
}

func Info(msg string) {
	output("INFO", msg)
}

func Infof(format string, v ...interface{}) {
	output("INFO", fmt.Sprintf(format, v...))
}

func Warn(msg string) {
	output("WARN", msg)
}

func Warnf(format string, v ...interface{}) {
	output("WARN", fmt.Sprintf(format, v...))
}

func Error(msg string) {
	output("ERROR", msg)
}

func Errorf(format string, v ...interface{}) {
	output("ERROR", fmt.Sprintf(format, v...))
}

func Fatalf(format string, v ...interface{}) {
	output("FATAL", fmt.Sprintf(format, v...))
	os.Exit(1)
}
