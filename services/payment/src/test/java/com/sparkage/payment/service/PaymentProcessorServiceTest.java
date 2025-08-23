package com.sparkage.payment.service;

import com.sparkage.payment.api.dto.PaymentRequest;
import com.sparkage.payment.api.dto.PaymentResponse;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

class PaymentProcessorServiceTest {

    @Test
    void approves_valid_supported_method_and_positive_amount() {
        PaymentProcessorService svc = new PaymentProcessorService();
        PaymentRequest req = new PaymentRequest();
        req.setOrderId(123L);
        req.setPaymentMethod("CARD");
        req.setAmount(new BigDecimal("10.00"));
        req.setPaymentDetails("token-abc");

        PaymentResponse resp = svc.process(req);
        assertEquals("APPROVED", resp.getStatus());
        assertNotNull(resp.getTransactionId());
        assertEquals(123L, resp.getOrderId());
        assertEquals(new BigDecimal("10.00"), resp.getAmount());
        assertEquals("CARD", resp.getPaymentMethod());
        assertNotNull(resp.getProcessedAt());
    }

    @Test
    void declines_unsupported_method() {
        PaymentProcessorService svc = new PaymentProcessorService();
        PaymentRequest req = new PaymentRequest();
        req.setOrderId(1L);
        req.setPaymentMethod("BITCOIN");
        req.setAmount(new BigDecimal("5.00"));
        req.setPaymentDetails("x");

        PaymentResponse resp = svc.process(req);
        assertEquals("DECLINED", resp.getStatus());
    }

    @Test
    void declines_non_positive_amount() {
        PaymentProcessorService svc = new PaymentProcessorService();
        PaymentRequest req = new PaymentRequest();
        req.setOrderId(1L);
        req.setPaymentMethod("CARD");
        req.setAmount(new BigDecimal("0.00"));
        req.setPaymentDetails("x");

        PaymentResponse resp = svc.process(req);
        assertEquals("DECLINED", resp.getStatus());
    }
}
