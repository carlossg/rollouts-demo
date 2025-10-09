package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestGetColor_NoBody(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/color", nil)
	w := httptest.NewRecorder()

	getColor(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var color string
	if err := json.Unmarshal(w.Body.Bytes(), &color); err != nil {
		t.Errorf("Failed to parse response: %v", err)
	}

	// Should return one of the valid colors
	validColors := map[string]bool{"red": true, "orange": true, "yellow": true, "green": true, "blue": true, "purple": true}
	if !validColors[color] {
		t.Errorf("Expected a valid color, got %s", color)
	}
}

func TestGetColor_EmptyArray(t *testing.T) {
	body := []byte("[]")
	req := httptest.NewRequest(http.MethodPost, "/color", bytes.NewReader(body))
	w := httptest.NewRecorder()

	getColor(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var color string
	if err := json.Unmarshal(w.Body.Bytes(), &color); err != nil {
		t.Errorf("Failed to parse response: %v", err)
	}

	// Should return one of the valid colors
	validColors := map[string]bool{"red": true, "orange": true, "yellow": true, "green": true, "blue": true, "purple": true}
	if !validColors[color] {
		t.Errorf("Expected a valid color, got %s", color)
	}
}

func TestGetColor_WithColorEnvSet(t *testing.T) {
	// Set COLOR env var to a specific color
	originalColor := os.Getenv("COLOR")
	os.Setenv("COLOR", "red")
	defer func() {
		if originalColor == "" {
			os.Unsetenv("COLOR")
		} else {
			os.Setenv("COLOR", originalColor)
		}
	}()

	// Reload color variable
	color = os.Getenv("COLOR")

	req := httptest.NewRequest(http.MethodPost, "/color", nil)
	w := httptest.NewRecorder()

	getColor(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var returnedColor string
	if err := json.Unmarshal(w.Body.Bytes(), &returnedColor); err != nil {
		t.Errorf("Failed to parse response: %v", err)
	}

	if returnedColor != "red" {
		t.Errorf("Expected 'red', got %s", returnedColor)
	}
}

func TestGetColor_WithColorParameters(t *testing.T) {
	params := []colorParameters{
		{Color: "blue", DelayLength: 0},
		{Color: "red", DelayLength: 0},
	}
	body, _ := json.Marshal(params)

	// Set COLOR env var to red
	originalColor := os.Getenv("COLOR")
	os.Setenv("COLOR", "red")
	defer func() {
		if originalColor == "" {
			os.Unsetenv("COLOR")
		} else {
			os.Setenv("COLOR", originalColor)
		}
	}()

	// Reload color variable
	color = os.Getenv("COLOR")

	req := httptest.NewRequest(http.MethodPost, "/color", bytes.NewReader(body))
	w := httptest.NewRecorder()

	getColor(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var returnedColor string
	if err := json.Unmarshal(w.Body.Bytes(), &returnedColor); err != nil {
		t.Errorf("Failed to parse response: %v", err)
	}

	if returnedColor != "red" {
		t.Errorf("Expected 'red', got %s", returnedColor)
	}
}

func TestGetColor_AllColors(t *testing.T) {
	// Test that all colors work without panicking
	testColors := []string{"red", "orange", "yellow", "green", "blue", "purple"}

	for _, testColor := range testColors {
		t.Run(testColor, func(t *testing.T) {
			// Set COLOR env var to specific color
			originalColor := os.Getenv("COLOR")
			os.Setenv("COLOR", testColor)
			defer func() {
				if originalColor == "" {
					os.Unsetenv("COLOR")
				} else {
					os.Setenv("COLOR", originalColor)
				}
			}()

			// Reload color variable
			color = os.Getenv("COLOR")

			req := httptest.NewRequest(http.MethodPost, "/color", nil)
			w := httptest.NewRecorder()

			// This should not panic
			getColor(w, req)

			if w.Code != http.StatusOK {
				t.Errorf("Expected status 200 for color %s, got %d", testColor, w.Code)
			}

			var returnedColor string
			if err := json.Unmarshal(w.Body.Bytes(), &returnedColor); err != nil {
				t.Errorf("Failed to parse response for color %s: %v", testColor, err)
			}

			if returnedColor != testColor {
				t.Errorf("Expected '%s', got %s", testColor, returnedColor)
			}
		})
	}
}

func TestRandomColor(t *testing.T) {
	// Test that randomColor returns a valid color
	validColors := map[string]bool{"red": true, "orange": true, "yellow": true, "green": true, "blue": true, "purple": true}
	
	for i := 0; i < 100; i++ {
		color := randomColor()
		if !validColors[color] {
			t.Errorf("randomColor returned invalid color: %s", color)
		}
	}
}

func TestPrintColor(t *testing.T) {
	testCases := []struct {
		color      string
		statusCode int
	}{
		{"red", http.StatusOK},
		{"green", http.StatusOK},
		{"blue", http.StatusInternalServerError},
		{"", http.StatusOK},
	}

	for _, tc := range testCases {
		t.Run(tc.color, func(t *testing.T) {
			w := httptest.NewRecorder()
			printColor(tc.color, w, tc.statusCode)

			if w.Code != tc.statusCode {
				t.Errorf("Expected status %d, got %d", tc.statusCode, w.Code)
			}

			expected := "\"" + tc.color + "\""
			if w.Body.String() != expected {
				t.Errorf("Expected body %s, got %s", expected, w.Body.String())
			}
		})
	}
}
