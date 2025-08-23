package com.sparkage.payment.api.dto;

import java.math.BigDecimal;
import java.time.Instant;

public class PaymentResponse {
    private String status; // e.g., APPROVED, DECLINED
    private String transactionId;
    private Long orderId;
    private String paymentMethod;
    private BigDecimal amount;
    private Instant processedAt;

    public PaymentResponse() {}

    public PaymentResponse(String status, String transactionId, Long orderId, String paymentMethod, BigDecimal amount, Instant processedAt) {
        this.status = status;
        this.transactionId = transactionId;
        this.orderId = orderId;
        this.paymentMethod = paymentMethod;
        this.amount = amount;
        this.processedAt = processedAt;
    }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getTransactionId() { return transactionId; }
    public void setTransactionId(String transactionId) { this.transactionId = transactionId; }

    public Long getOrderId() { return orderId; }
    public void setOrderId(Long orderId) { this.orderId = orderId; }

    public String getPaymentMethod() { return paymentMethod; }
    public void setPaymentMethod(String paymentMethod) { this.paymentMethod = paymentMethod; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public Instant getProcessedAt() { return processedAt; }
    public void setProcessedAt(Instant processedAt) { this.processedAt = processedAt; }
}
