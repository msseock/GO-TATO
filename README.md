# 일단감자 🥔
<img width="1810" height="675" alt="image" src="https://github.com/user-attachments/assets/99299117-71b5-412d-989d-986583f5b71b" />

> GPS 기반 출근 인증 iOS 앱

📆 2026. 03

- **출석 미션 생성**: 장소 · 반복 요일 · 마감 시간을 설정해 나만의 출근 루틴 등록. Wi-Fi SSID 일치, 사진 유사도 검증을 선택적으로 추가 가능
- **근처 알림**: 미션 장소 반경 100m 진입 시 백그라운드에서 푸시 알림 발송 (지오펜스 기반)
- **출석 통계**: 월별 달력으로 성공 · 지각 · 실패 현황 시각화. 출석률 · 지각 횟수 · 절약 시간 제공
- **홈 화면 위젯**: 현재 미션 상태를 홈 화면에서 바로 확인. 지오펜스 진입 시 백그라운드에서 자동 갱신



## 주요 기능

### ✔️ 미션 설정
- 네이버 지역 검색 API로 장소 검색 후 미션 등록
- 반복 요일 · 기간 · 출근 마감 시간 설정
- 선택 옵션: Wi-Fi SSID 인증, 사진 인증

| 미션 설정 | 대시보드 | 기록 |
|:---:|:---:|:---:|
| <img width="2358" height="5130" alt="image" src="https://github.com/user-attachments/assets/8f0045dc-bffb-4e75-abe3-422c0499e09c" /> | <img width="2412" height="5244" alt="image" src="https://github.com/user-attachments/assets/ae906f25-eeba-418f-a82e-ba36140e5fb8" /> | <img width="2412" height="5244" alt="image" src="https://github.com/user-attachments/assets/2c197a29-67b5-4389-a5d0-16286b20fed6" /> |



### ✔️ 출근 인증 대시보드
- 목적지 반경 100m 이내 + (설정 시) Wi-Fi 연결 확인 → 인증 버튼 활성화
- 사진 인증 미션: Apple Vision Framework의 `VNFeaturePrintObservation`으로 등록 사진과 현재 사진의 유사도를 비교해 인증
- 인증 성공/지각/실패/미인증 확정 상태를 실시간으로 표시

| 근처 도착 | 인증 성공 | 실패 |
|:---:|:---:|:---:|
| <img width="2171" height="4720" alt="image" src="https://github.com/user-attachments/assets/6e1aa90b-f9ee-4448-a3ad-e486518b5d62" /> | <img width="2412" height="5244" alt="image" src="https://github.com/user-attachments/assets/ae906f25-eeba-418f-a82e-ba36140e5fb8" /> | <img width="2171" height="4720" alt="image" src="https://github.com/user-attachments/assets/40eac795-cbe9-4e2e-89e6-ce622716c2f8" /> |

### ✔️ 홈 화면 위젯
- `WidgetKit` + `AppIntents` 기반 소형 위젯
- App Group을 통해 메인 앱과 스냅샷 공유
- 지오펜스 진입 시 백그라운드에서 위젯 상태 자동 갱신 (`WidgetCenter.reloadTimelines`)
- `AppIntents`의 `WidgetConfigurationIntent`로 위젯 롱프레스 설정 화면에서 표시할 미션을 직접 선택 가능

| 이동 중 | 도착 (인증 가능) | 출근 완료 |
|:---:|:---:|:---:|
| <img width="986" height="986" alt="image" src="https://github.com/user-attachments/assets/8389ec86-d162-4893-aabc-04a4e216b04b" /> | <img width="986" height="986" alt="image" src="https://github.com/user-attachments/assets/387e0a59-dcca-4d18-aa78-07ad4290a50c" /> | <img width="986" height="986" alt="image" src="https://github.com/user-attachments/assets/27218a6e-fe43-4dfb-af6c-8732a23b5ac3" /> |

### ✔️ 출석 기록
- 월별 달력으로 출석 현황 시각화 (성공 / 지각 / 실패 dot pill)
- 출석률 · 지각 횟수 · 절약 시간 통계



## 기술 스택

![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![iOS](https://img.shields.io/badge/iOS-18.6+-blue?logo=apple)
![RxSwift](https://img.shields.io/badge/RxSwift-6-red)
![SnapKit](https://img.shields.io/badge/SnapKit-DSL-green)
![CoreData](https://img.shields.io/badge/CoreData+CloudKit-local%20sync-lightgrey)
![WidgetKit](https://img.shields.io/badge/WidgetKit-AppIntents-purple)

| 범주 | 사용 기술 |
|---|---|
| 반응형 UI | RxSwift / RxCocoa |
| 레이아웃 | SnapKit (코드 베이스, 스토리보드 미사용) |
| 네트워킹 | Alamofire + Routable 패턴 |
| 지도 | NMapsMap (네이버 지도 SDK) |
| 로컬 저장 | CoreData + CloudKit 동기화 |
| 위치 | CoreLocation — 지오펜스 모니터링 |
| 사진 인증 | AVFoundation + Vision Framework |
| 위젯 | WidgetKit + AppIntents |

---

## 아키텍처

- MVVM + RxSwift. 모든 사용자 이벤트는 `Input`으로 진입하고 UI 업데이트는 `Output`으로만 방출

```
ViewController
  └─ Input  ──▶  ViewModel.transform(input:)
                      └─ Output  ──▶  View binding (Driver / Signal)
```

- ViewModel은 CoreData를 직접 참조하지 않고 Repository 프로토콜을 통해서만 데이터에 접근

```
ViewModel  ──▶  RepositoryProtocol  ──▶  CoreDataRepository
```

### 폴더 구조

```
GoTato/
├── Application/        # AppDelegate, SceneDelegate
├── Resource/           # GTTColor, GTTFont, GTTIcon
├── Data/
│   ├── CoreData/       # 엔티티 정의 및 Utils 익스텐션
│   └── Repository/     # CRUD 추상화 레이어
├── Network/            # Routable 라우터, Alamofire 래퍼
├── Presentation/
│   ├── Common/         # BaseViewController, BaseViewModel, 공통 컴포넌트
│   ├── Onboard/
│   ├── MissionSetup/
│   ├── Dashboard/
│   ├── History/
│   └── MissionDetail/
├── Utils/              # GeofenceManager, LocationService, WifiService 등
└── BasicWidget/        # WidgetKit 익스텐션 타겟
```

