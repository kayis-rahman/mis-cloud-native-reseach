package com.sparkage.identity.api.dto;

import jakarta.annotation.Nullable;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Size;

public class UpdateUserRequest {
    // Optional fields; when provided, must satisfy constraints
    @Size(min = 3, max = 50, message = "username must be between 3 and 50 characters")
    private String username; // nullable

    @Email(message = "email must be a valid email address")
    private String email; // nullable

    @Size(min = 8, max = 100, message = "password must be at least 8 characters")
    private String password; // nullable

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
}
