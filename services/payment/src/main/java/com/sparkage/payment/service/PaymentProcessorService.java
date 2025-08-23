package com.sparkage.payment.service;

import com.sparkage.payment.api.dto.PaymentRequest;
import com.sparkage.payment.api.dto.PaymentResponse;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public class PaymentProcessorService {

    private static final Set<String> SUPPORTED_METHODS = Set.of("CARD", "WALLET", "UPI", "NETBANKING", "COD");

    // In-memory store of processed payments keyed by transactionId
    private final Map<String, PaymentResponse> store = new ConcurrentHashMap<>();

    public PaymentResponse process(PaymentRequest req) {
        // Simple deterministic logic for demo/testing purposes
        String method = req.getPaymentMethod() == null ? "" : req.getPaymentMethod().toUpperCase();
        boolean methodSupported = SUPPORTED_METHODS.contains(method);
        boolean amountValid = req.getAmount() != null && req.getAmount().signum() > 0;

        String status = (methodSupported && amountValid) ? "APPROVED" : "DECLINED";
        String txId = UUID.randomUUID().toString();
        PaymentResponse resp = new PaymentResponse(status, txId, req.getOrderId(), method, req.getAmount(), Instant.now());
        store.put(txId, resp);
        return resp;
    }

    public Optional<PaymentResponse> getById(String paymentId) {
        return Optional.ofNullable(store.get(paymentId));
    }
}
