package com.example.finance_client.notification.utils

import java.security.MessageDigest

object EventIdGenerator {
    fun generate(packageName: String, timestamp: Long, title: String, content: String): String {
        val raw = "${packageName}_${timestamp}_${title}_${content}"
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = digest.digest(raw.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
