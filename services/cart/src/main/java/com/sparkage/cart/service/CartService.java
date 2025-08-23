package com.sparkage.cart.service;

import com.sparkage.cart.model.Cart;
import com.sparkage.cart.model.CartItem;
import org.springframework.stereotype.Service;

import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class CartService {
    private final Map<Long, Cart> carts = new ConcurrentHashMap<>();

    public static class NotFoundException extends RuntimeException {
        public NotFoundException(String message) { super(message); }
    }

    public synchronized Cart addItem(Long userId, Long productId, int quantity) {
        if (userId == null) throw new IllegalArgumentException("userId cannot be null");
        if (productId == null) throw new IllegalArgumentException("productId cannot be null");
        if (quantity < 1) throw new IllegalArgumentException("quantity must be >= 1");

        Cart cart = carts.computeIfAbsent(userId, Cart::new);
        cart.addOrUpdateItem(productId, quantity);
        return cart;
    }

    public synchronized Cart updateItemQuantity(Long userId, Long productId, int quantity) {
        if (userId == null) throw new IllegalArgumentException("userId cannot be null");
        if (productId == null) throw new IllegalArgumentException("productId cannot be null");
        if (quantity < 1) throw new IllegalArgumentException("quantity must be >= 1");

        Cart cart = carts.get(userId);
        if (cart == null) throw new NotFoundException("Cart not found for userId=" + userId);
        CartItem item = cart.getItems().stream()
                .filter(i -> i.getProductId().equals(productId))
                .findFirst()
                .orElse(null);
        if (item == null) throw new NotFoundException("Item not found in cart: productId=" + productId);
        item.setQuantity(quantity);
        return cart;
    }

    public synchronized Cart removeItem(Long userId, Long productId) {
        if (userId == null) throw new IllegalArgumentException("userId cannot be null");
        if (productId == null) throw new IllegalArgumentException("productId cannot be null");
        Cart cart = carts.get(userId);
        if (cart == null) throw new NotFoundException("Cart not found for userId=" + userId);
        boolean removed = false;
        Iterator<CartItem> it = cart.getItems().iterator();
        while (it.hasNext()) {
            if (productId.equals(it.next().getProductId())) {
                it.remove();
                removed = true;
                break;
            }
        }
        if (!removed) throw new NotFoundException("Item not found in cart: productId=" + productId);
        return cart;
    }

    public synchronized Cart clearCart(Long userId) {
        if (userId == null) throw new IllegalArgumentException("userId cannot be null");
        Cart cart = carts.get(userId);
        if (cart == null) {
            return new Cart(userId);
        }
        cart.getItems().clear();
        return cart;
    }

    public Cart getCart(Long userId) {
        return carts.getOrDefault(userId, new Cart(userId));
    }

    public void clearAll() {
        carts.clear();
    }
}