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

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping("/register")
    public ResponseEntity<UserResponse> register(@Valid @RequestBody UserRegistrationRequest request) {
        User user = userService.register(request);
        UserResponse response = new UserResponse(user.getId(), user.getUsername(), user.getEmail(), user.getCreatedAt());
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
}