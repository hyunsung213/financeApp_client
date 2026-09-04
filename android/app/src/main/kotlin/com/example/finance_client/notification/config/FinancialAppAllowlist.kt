package com.example.finance_client.notification.config

object FinancialAppAllowlist {
    private val ALLOWED_PACKAGES = mapOf(
        // KB 국민카드 / KB 국민은행
        "com.kbcard.cxh.appcard" to "KB Pay (국민카드)",
        "com.kbstar.kbbank" to "KB스타뱅킹",
        "com.kbstar.liivm" to "리브M",
        
        // 신한카드 / 신한은행
        "com.shcard.smartpay" to "신한 SOL페이",
        "com.shinhan.sbanking" to "신한 SOL뱅크",
        
        // 카카오뱅크 / 카카오페이
        "com.kakaobank.channel" to "카카오뱅크",
        "com.kakaopay.app" to "카카오페이",
        
        // 토스 (토스뱅크 / 토스증권 / 토스페이 통합)
        "viva.republica.toss" to "토스",
        
        // 현대카드
        "com.hyundaicard.appcard" to "현대카드",
        
        // 삼성카드
        "kr.co.samsungcard.mpocket" to "삼성카드 (모니모)",
        "com.monimo" to "모니모",
        
        // 롯데카드
        "com.lcacApp" to "디지로카 (롯데카드)",
        
        // 우리카드 / 우리은행
        "com.wooricard.smartapp" to "우리WON카드",
        "com.wooribank.smart.npib" to "우리WON뱅킹",
        
        // 하나카드 / 하나은행
        "com.hanaskcard.paycla" to "하나원큐페이",
        "com.hanabank.ebk.channel.android.hananbank" to "하나원큐",
        
        // NH 농협카드 / NH 농협은행
        "nh.smart.nhallonepay" to "NH Pay",
        "nh.smart.banking" to "NH스마트뱅킹",
        "nh.smart.allonebank" to "올원뱅크",
        
        // BC카드
        "com.bccard.mobilecard" to "페이북/BC카드",
        
        // IBK 기업은행
        "com.ibk.neobanking" to "i-ONE Bank (기업은행)",
        
        // 케이뱅크
        "com.kbankwith.smartbank" to "케이뱅크",
        
        // SC제일은행
        "com.sc.smart" to "SC제일은행",
        
        // 네이버페이
        "com.nhn.android.search" to "네이버",
        "com.naver.pay" to "네이버페이",
        
        // 우체국스마트뱅킹
        "com.epost.psns.sbanking" to "우체국스마트뱅킹",

        // ADB Test Notification
        "com.android.shell" to "ADB 테스트 알림"
    )

    fun isAllowedPackage(packageName: String): Boolean {
        return ALLOWED_PACKAGES.containsKey(packageName)
    }

    fun getAppName(packageName: String): String {
        return ALLOWED_PACKAGES[packageName] ?: packageName
    }

    fun getAllowedPackages(): Set<String> {
        return ALLOWED_PACKAGES.keys
    }
}
