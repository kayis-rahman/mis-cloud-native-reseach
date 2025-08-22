package com.sparkage.cart.api.dto;

import java.util.ArrayList;
import java.util.List;

public class CartResponse {
    private Long userId;
    private List<CartItemResponse> items = new ArrayList<>();

    public CartResponse() {}

    public CartResponse(Long userId, List<CartItemResponse> items) {
        this.userId = userId;
        this.items = items;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public List<CartItemResponse> getItems() {
        return items;
    }

    public void setItems(List<CartItemResponse> items) {
        this.items = items;
    }
}