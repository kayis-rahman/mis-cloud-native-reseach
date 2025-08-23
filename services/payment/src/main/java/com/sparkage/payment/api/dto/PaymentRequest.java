package com.sparkage.payment.api.dto;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;

public class PaymentRequest {
    @NotNull
    private Long orderId;

    @NotBlank
    private String paymentMethod; // e.g., "CARD", "WALLET", "COD"

    @NotNull
    @DecimalMin(value = "0.01", inclusive = true, message = "amount must be greater than 0")
    private BigDecimal amount;

    // Simplify payment details as opaque string (e.g., token or masked card)
    @NotBlank
    private String paymentDetails;

    public PaymentRequest() {}

    public Long getOrderId() { return orderId; }
    public void setOrderId(Long orderId) { this.orderId = orderId; }

    public String getPaymentMethod() { return paymentMethod; }
    public void setPaymentMethod(String paymentMethod) { this.paymentMethod = paymentMethod; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getPaymentDetails() { return paymentDetails; }
    public void setPaymentDetails(String paymentDetails) { this.paymentDetails = paymentDetails; }
}
