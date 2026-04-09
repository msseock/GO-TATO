//
//  WifiService.swift
//  GoTato
//

import Foundation
import SystemConfiguration.CaptiveNetwork
#if canImport(NetworkExtension)
import NetworkExtension
#endif

/// 현재 연결된 WiFi의 SSID를 조회한다.
///
/// iOS 제약:
/// - 주변 WiFi 스캔은 불가능. 오직 "현재 연결된 WiFi 1개"만 조회할 수 있다.
/// - `Access WiFi Information` capability + 위치 권한(WhenInUse 이상) 둘 다 필요.
/// - 시뮬레이터에서는 항상 nil을 반환한다 → 실기기 테스트 필수.
enum WifiService {
    /// 현재 연결된 WiFi의 SSID. 미연결/권한 부족/시뮬레이터 환경 등에서는 nil.
    static func getCurrentSSID() -> String? {
        #if os(iOS)
        print("[WiFi] === getCurrentSSID 시작 ===")

        guard let cfArray = CNCopySupportedInterfaces() else {
            print("[WiFi] ❌ CNCopySupportedInterfaces() == nil — capability 누락 또는 entitlement 미적용 가능성")
            return nil
        }
        guard let interfaces = cfArray as? [String] else {
            print("[WiFi] ❌ interfaces 캐스팅 실패: \(cfArray)")
            return nil
        }
        print("[WiFi] interfaces 목록: \(interfaces) (count: \(interfaces.count))")

        if interfaces.isEmpty {
            print("[WiFi] ❌ interfaces 배열이 비어있음 — WiFi 미연결 또는 권한 문제")
            return nil
        }

        for interface in interfaces {
            print("[WiFi] interface 시도: \(interface)")
            guard let infoCF = CNCopyCurrentNetworkInfo(interface as CFString) else {
                print("[WiFi]   ↳ CNCopyCurrentNetworkInfo == nil (위치 권한 거부/미연결/capability 누락)")
                continue
            }
            guard let info = infoCF as? [String: Any] else {
                print("[WiFi]   ↳ info 캐스팅 실패")
                continue
            }
            print("[WiFi]   ↳ info 전체: \(info)")
            guard let ssid = info[kCNNetworkInfoKeySSID as String] as? String else {
                print("[WiFi]   ↳ SSID 키 없음")
                continue
            }
            if ssid.isEmpty {
                print("[WiFi]   ↳ SSID 비어있음")
                continue
            }
            print("[WiFi] ✅ SSID 획득: \(ssid)")
            return ssid
        }
        print("[WiFi] ❌ 모든 interface에서 SSID 획득 실패")
        return nil
        #else
        return nil
        #endif
    }

    /// 현재 연결된 WiFi가 `target`과 일치하는지. (sync, 레거시 API 사용)
    static func isConnectedToSSID(_ target: String) -> Bool {
        guard let current = getCurrentSSID() else { return false }
        return current == target
    }

    /// iOS 14+ 권장 API. NEHotspotNetwork.fetchCurrent 사용.
    /// CNCopyCurrentNetworkInfo가 nil 리턴하는 환경에서도 동작하는 케이스가 많음.
    /// Access WiFi Information capability + 위치 권한(WhenInUse 이상) 필요.
    static func fetchCurrentSSID(completion: @escaping (String?) -> Void) {
        #if canImport(NetworkExtension) && os(iOS)
        print("[WiFi] === fetchCurrentSSID (NEHotspotNetwork) 시작 ===")
        NEHotspotNetwork.fetchCurrent { network in
            if let network = network {
                print("[WiFi] ✅ NEHotspotNetwork: ssid=\(network.ssid), bssid=\(network.bssid), signalStrength=\(network.signalStrength)")
                DispatchQueue.main.async { completion(network.ssid) }
            } else {
                print("[WiFi] ❌ NEHotspotNetwork.fetchCurrent → nil")
                // 폴백: 레거시 API
                let legacy = getCurrentSSID()
                DispatchQueue.main.async { completion(legacy) }
            }
        }
        #else
        completion(nil)
        #endif
    }
}
