package com.sparkage.cart.api.dto;

import jakarta.validation.constraints.Min;

public class UpdateCartItemQuantityRequest {
    @Min(1)
    private int quantity;

    public UpdateCartItemQuantityRequest() {}

    public UpdateCartItemQuantityRequest(int quantity) {
        this.quantity = quantity;
    }

    public int getQuantity() {
        return quantity;
    }

    public void setQuantity(int quantity) {
        this.quantity = quantity;
    }
}
