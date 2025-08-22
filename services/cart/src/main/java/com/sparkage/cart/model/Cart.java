package com.sparkage.cart.model;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

public class Cart {
    private Long userId;
    private List<CartItem> items = new ArrayList<>();

    public Cart() {}

    public Cart(Long userId) {
        this.userId = userId;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public List<CartItem> getItems() {
        return items;
    }

    public void setItems(List<CartItem> items) {
        this.items = items;
    }

    public void addOrUpdateItem(Long productId, int quantity) {
        Optional<CartItem> existing = items.stream()
                .filter(i -> i.getProductId().equals(productId))
                .findFirst();
        if (existing.isPresent()) {
            CartItem item = existing.get();
            item.setQuantity(item.getQuantity() + quantity);
        } else {
            items.add(new CartItem(productId, quantity));
        }
    }
}