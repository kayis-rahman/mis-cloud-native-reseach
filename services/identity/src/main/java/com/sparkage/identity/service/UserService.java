package com.sparkage.identity.service;

import com.sparkage.identity.api.dto.UserRegistrationRequest;
import com.sparkage.identity.model.User;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@Service
public class UserService {
    private final UserRepository repo;

    public UserService(UserRepository repo) {
        this.repo = repo;
    }

    public User register(UserRegistrationRequest req) {
        String normUsername = req.getUsername().trim();
        String normEmail = req.getEmail().trim();

        Optional<User> existingByUsername = repo.findByUsernameIgnoreCase(normUsername);
        if (existingByUsername.isPresent()) {
            throw new UserAlreadyExistsException("username already taken");
        }
        Optional<User> existingByEmail = repo.findByEmailIgnoreCase(normEmail);
        if (existingByEmail.isPresent()) {
            throw new UserAlreadyExistsException("email already registered");
        }

        String hash = hashPassword(req.getPassword());

        User user = new User();
        user.setUsername(normUsername);
        user.setEmail(normEmail);
        user.setPasswordHash(hash);
        repo.save(user);
        return user;
    }

    private String hashPassword(String password) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = digest.digest(password.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : bytes) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }

    public static class UserAlreadyExistsException extends RuntimeException {
        public UserAlreadyExistsException(String message) { super(message); }
    }
}