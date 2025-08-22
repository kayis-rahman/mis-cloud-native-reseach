package com.sparkage.identity.service;

import com.sparkage.identity.model.User;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.time.Instant;
import java.util.Date;

@Service
public class JwtService {

    private final SecretKey key;
    private final String issuer;
    private final long expirationSeconds;

    public JwtService(
            @Value("${jwt.secret:changeme-please-ensure-32-bytes-min}") String secret,
            @Value("${jwt.issuer:identity-service}") String issuer,
            @Value("${jwt.expiration-seconds:3600}") long expirationSeconds
    ) {
        // Accept either base64-encoded secret or raw string; if base64 decode fails, use raw bytes
        SecretKey derivedKey;
        try {
            byte[] decoded = Decoders.BASE64.decode(secret);
            derivedKey = Keys.hmacShaKeyFor(decoded);
        } catch (Exception e) {
            derivedKey = Keys.hmacShaKeyFor(secret.getBytes());
        }
        this.key = derivedKey;
        this.issuer = issuer;
        this.expirationSeconds = expirationSeconds;
    }

    public String createToken(User user) {
        Instant now = Instant.now();
        Instant exp = now.plusSeconds(expirationSeconds);
        return Jwts.builder()
                .setSubject(user.getId().toString())
                .setIssuer(issuer)
                .setIssuedAt(Date.from(now))
                .setExpiration(Date.from(exp))
                .claim("username", user.getUsername())
                .claim("email", user.getEmail())
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();
    }
}