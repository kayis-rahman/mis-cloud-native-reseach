package com.sparkage.payment.service;

import com.sparkage.payment.api.dto.PaymentRequest;
import com.sparkage.payment.api.dto.PaymentResponse;

import java.time.Instant;
import java.util.Set;
import java.util.UUID;

public class PaymentProcessorService {

    private static final Set<String> SUPPORTED_METHODS = Set.of("CARD", "WALLET", "UPI", "NETBANKING", "COD");

    public PaymentResponse process(PaymentRequest req) {
        // Simple deterministic logic for demo/testing purposes
        String method = req.getPaymentMethod() == null ? "" : req.getPaymentMethod().toUpperCase();
        boolean methodSupported = SUPPORTED_METHODS.contains(method);
        boolean amountValid = req.getAmount() != null && req.getAmount().signum() > 0;

        String status = (methodSupported && amountValid) ? "APPROVED" : "DECLINED";
        String txId = UUID.randomUUID().toString();
        return new PaymentResponse(status, txId, req.getOrderId(), method, req.getAmount(), Instant.now());
    }
}
