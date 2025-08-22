package com.sparkage.cart.service;

import com.sparkage.cart.model.Cart;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class CartService {
    private final Map<Long, Cart> carts = new ConcurrentHashMap<>();

    public synchronized Cart addItem(Long userId, Long productId, int quantity) {
        if (userId == null) throw new IllegalArgumentException("userId cannot be null");
        if (productId == null) throw new IllegalArgumentException("productId cannot be null");
        if (quantity < 1) throw new IllegalArgumentException("quantity must be >= 1");

        Cart cart = carts.computeIfAbsent(userId, Cart::new);
        cart.addOrUpdateItem(productId, quantity);
        return cart;
    }

    public Cart getCart(Long userId) {
        return carts.getOrDefault(userId, new Cart(userId));
    }

    public void clearAll() {
        carts.clear();
    }
}