package com.sparkage.order.api.dto;

import java.time.Instant;

public class OrderResponse {
    private Long id;
    private Long userId;
    private Long cartId;
    private String paymentInfo;
    private String shippingAddress;
    private String status;
    private Instant createdAt;

    public OrderResponse(Long id, Long userId, Long cartId, String paymentInfo, String shippingAddress, String status, Instant createdAt) {
        this.id = id;
        this.userId = userId;
        this.cartId = cartId;
        this.paymentInfo = paymentInfo;
        this.shippingAddress = shippingAddress;
        this.status = status;
        this.createdAt = createdAt;
    }

    public Long getId() { return id; }
    public Long getUserId() { return userId; }
    public Long getCartId() { return cartId; }
    public String getPaymentInfo() { return paymentInfo; }
    public String getShippingAddress() { return shippingAddress; }
    public String getStatus() { return status; }
    public Instant getCreatedAt() { return createdAt; }
}
