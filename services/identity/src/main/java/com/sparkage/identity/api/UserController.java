package com.sparkage.identity.api;

import com.sparkage.identity.api.dto.UserRegistrationRequest;
import com.sparkage.identity.api.dto.UserResponse;
import com.sparkage.identity.model.User;
import com.sparkage.identity.service.UserService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/users")
@Validated
public class UserController {

    private final UserService userService;
    private final com.sparkage.identity.service.JwtService jwtService;

    public UserController(UserService userService, com.sparkage.identity.service.JwtService jwtService) {
        this.userService = userService;
        this.jwtService = jwtService;
    }

    @PostMapping("/register")
    public ResponseEntity<UserResponse> register(@Valid @RequestBody UserRegistrationRequest request) {
        User user = userService.register(request);
        UserResponse response = new UserResponse(user.getId(), user.getUsername(), user.getEmail(), user.getCreatedAt());
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PostMapping("/login")
    public ResponseEntity<com.sparkage.identity.api.dto.LoginResponse> login(@Valid @RequestBody com.sparkage.identity.api.dto.LoginRequest request) {
        User user = userService.authenticate(request.getUsernameOrEmail(), request.getPassword());
        String token = jwtService.createToken(user);
        UserResponse userResp = new UserResponse(user.getId(), user.getUsername(), user.getEmail(), user.getCreatedAt());
        com.sparkage.identity.api.dto.LoginResponse resp = new com.sparkage.identity.api.dto.LoginResponse(token, userResp);
        return ResponseEntity.ok(resp);
    }

    @GetMapping("/{userId}")
    public ResponseEntity<UserResponse> getById(@PathVariable java.util.UUID userId) {
        User user = userService.getById(userId);
        UserResponse response = new UserResponse(user.getId(), user.getUsername(), user.getEmail(), user.getCreatedAt());
        return ResponseEntity.ok(response);
    }
}