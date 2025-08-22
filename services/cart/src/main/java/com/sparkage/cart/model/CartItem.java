package com.sparkage.cart.model;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

public class CartItem {
    @NotNull
    private Long productId;

    @Min(1)
    private int quantity;

    public CartItem() {
    }

    public CartItem(Long productId, int quantity) {
        this.productId = productId;
        this.quantity = quantity;
    }

    public Long getProductId() {
        return productId;
    }

    public void setProductId(Long productId) {
        this.productId = productId;
    }

    public int getQuantity() {
        return quantity;
    }

    public void setQuantity(int quantity) {
        this.quantity = quantity;
    }
}