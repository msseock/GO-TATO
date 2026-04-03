//
//  LocationSelectViewController.swift
//  GoTato
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import NMapsMap

struct SelectedLocation {
    let name: String
    let address: String
    let lati: Double
    let longi: Double
    let mapx: Int
    let mapy: Int
}

final class LocationSelectViewController: BaseViewController {

    // MARK: - Properties

    private let viewModel = LocationSelectViewModel()
    private let disposeBag = DisposeBag()
    
    // Inputs (Subjects for ViewModel)
    private let itemTappedSubject = PublishSubject<Int>()
    private let ctaTappedSubject  = PublishSubject<Void>()

    // Local State
    private var currentItems: [NaverLocalItem] = []
    private var currentSelectedIndex: Int?

    // Callbacks
    var onLocationConfirmed: ((SelectedLocation) -> Void)?

    // MARK: - UI Components

    private let titleLabel   = UILabel()

    // Search
    private let searchContainer = UIView()
    private let searchIconView  = UIImageView()
    private let searchField     = UITextField()
    private let clearButton     = UIButton()

    // Result list
    private let rListContainer = UIView()
    private let tableView      = UITableView()
    private let emptyView      = UIView()

    // Map preview
    private let mapPreviewContainer = UIView()
    private var customMapView: CustomNMView?

    // CTA
    private let ctaButton = GTTMainButton(
        title: "여기로 정하기",
        icon: UIImage(systemName: "location.fill"),
        style: .secondary
    )

    // MARK: - Constraints

    private var rListHeightConstraint:      Constraint?
    private var mapPreviewHeightConstraint: Constraint?
    private var ctaBottomConstraint:        Constraint?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardObservers()
        setupKeyboardDismissGesture()
        bindViewModel()
    }

    private func setupKeyboardDismissGesture() {
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: - BaseViewController Overrides

    override func configureHierarchy() {
        view.addSubview(titleLabel)
        view.addSubview(searchContainer)
        searchContainer.addSubview(searchIconView)
        searchContainer.addSubview(searchField)
        searchContainer.addSubview(clearButton)
        view.addSubview(rListContainer)
        rListContainer.addSubview(tableView)
        rListContainer.addSubview(emptyView)
        view.addSubview(mapPreviewContainer)
        view.addSubview(ctaButton)
    }

    override func configureLayout() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        searchContainer.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(52)
        }

        searchIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(18)
        }

        clearButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(20)
        }

        searchField.snp.makeConstraints { make in
            make.leading.equalTo(searchIconView.snp.trailing).offset(10)
            make.trailing.equalTo(clearButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }

        rListContainer.snp.makeConstraints { make in
            make.top.equalTo(searchContainer.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(24)
            rListHeightConstraint = make.height.equalTo(0).constraint
        }

        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
        emptyView.snp.makeConstraints { $0.edges.equalToSuperview() }

        mapPreviewContainer.snp.makeConstraints { make in
            make.top.equalTo(rListContainer.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(24)
            mapPreviewHeightConstraint = make.height.equalTo(0).constraint
            make.bottom.lessThanOrEqualTo(ctaButton.snp.top).offset(-16)
        }

        ctaButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            ctaBottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide).inset(24).constraint
            make.height.equalTo(52)
        }
    }

    override func configureView() {
        view.backgroundColor = GTTColor.white

        titleLabel.text = "출근할 위치를\n정해볼까요?"
        titleLabel.font = GTTFont.dashboardTitle.font
        titleLabel.textColor = GTTColor.textPrimary
        titleLabel.numberOfLines = 2

        searchContainer.backgroundColor = GTTColor.white
        searchContainer.layer.cornerRadius = 14
        searchContainer.layer.borderColor = GTTColor.divider.cgColor
        searchContainer.layer.borderWidth = 1.5

        searchIconView.image = UIImage(systemName: "magnifyingglass")
        searchIconView.tintColor = GTTColor.textMuted
        searchIconView.contentMode = .scaleAspectFit

        searchField.font = GTTFont.caption.font
        searchField.textColor = GTTColor.textPrimary
        searchField.borderStyle = .none
        searchField.returnKeyType = .search
        searchField.attributedPlaceholder = NSAttributedString(
            string: "장소나 주소를 입력하세요",
            attributes: [.foregroundColor: GTTColor.textMuted, .font: GTTFont.caption.font]
        )

        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = GTTColor.textMuted
        clearButton.isHidden = true

        rListContainer.layer.cornerRadius = 0
        rListContainer.clipsToBounds = true
        rListContainer.isHidden = true
        rListContainer.backgroundColor = .clear

        tableView.register(LocationResultCell.self, forCellReuseIdentifier: "LocationResultCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.rowHeight = 65
        tableView.showsVerticalScrollIndicator = false

        mapPreviewContainer.layer.cornerRadius = 14
        mapPreviewContainer.clipsToBounds = true
        mapPreviewContainer.isHidden = true
        
        setupEmptyView()
        setupInternalActions()
    }

    // MARK: - Setup

    private func setupEmptyView() {
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass.circle"))
        icon.tintColor = GTTColor.tan
        icon.contentMode = .scaleAspectFit

        let titleLbl = UILabel()
        titleLbl.text = "검색결과가 없어요"
        titleLbl.font = UIFont(name: "Pretendard-Bold", size: 14) ?? GTTFont.caption.font
        titleLbl.textColor = GTTColor.textQuiet

        let subLbl = UILabel()
        subLbl.text = "다른 키워드로 검색해보세요"
        subLbl.font = GTTFont.badge.font
        subLbl.textColor = GTTColor.textMuted

        let stack = UIStackView(arrangedSubviews: [icon, titleLbl, subLbl])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8

        emptyView.addSubview(stack)
        stack.snp.makeConstraints { $0.center.equalToSuperview() }
        icon.snp.makeConstraints { $0.size.equalTo(32) }
        emptyView.isHidden = true
    }

    private func setupInternalActions() {
        searchField.rx.controlEvent(.editingDidEndOnExit)
            .subscribe(onNext: { [weak self] in
                self?.view.endEditing(true)
            })
            .disposed(by: disposeBag)

        clearButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self else { return }
                self.searchField.text = ""
                self.searchField.resignFirstResponder()
            })
            .disposed(by: disposeBag)

        ctaButton.onTap = { [weak self] in
            self?.ctaTappedSubject.onNext(())
        }
    }

    // MARK: - Binding

    private func bindViewModel() {
        let input = LocationSelectViewModel.Input(
            searchText: searchField.rx.text.orEmpty.asObservable(),
            clearTap: clearButton.rx.tap.asObservable(),
            itemTapped: itemTappedSubject.asObservable(),
            ctaTapped: ctaTappedSubject.asObservable()
        )
        
        let output = viewModel.transform(input: input)

        // Result List
        Driver.combineLatest(output.items, output.hasSearched, output.isEmptyResult)
            .drive(onNext: { [weak self] items, hasSearched, isEmptyResult in
                guard let self else { return }
                self.currentItems = items
                self.updateRListUI(items: items, hasSearched: hasSearched, isEmptyResult: isEmptyResult)
            })
            .disposed(by: disposeBag)

        // Selected Index
        output.selectedIndex
            .drive(onNext: { [weak self] idx in
                guard let self else { return }
                self.currentSelectedIndex = idx
                self.tableView.reloadData()
            })
            .disposed(by: disposeBag)

        // Map Coord
        output.mapCoord
            .drive(onNext: { [weak self] coord in
                self?.updateMapPreview(coord: coord)
            })
            .disposed(by: disposeBag)

        // CTA
        output.ctaEnabled
            .drive(ctaButton.rx.isEnabled)
            .disposed(by: disposeBag)
            
        output.ctaStyle
            .drive(onNext: { [weak self] style in
                self?.ctaButton.configure(style: style)
            })
            .disposed(by: disposeBag)

        // Confirmation
        output.locationConfirmed
            .emit(onNext: { [weak self] loc in
                self?.onLocationConfirmed?(loc)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - UI Updates

    private func updateRListUI(items: [NaverLocalItem], hasSearched: Bool, isEmptyResult: Bool) {
        if !hasSearched {
            rListContainer.isHidden = true
            rListHeightConstraint?.update(offset: 0)
            clearButton.isHidden = true
            UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
            return
        }

        clearButton.isHidden = false
        rListContainer.isHidden = false

        if isEmptyResult {
            tableView.isHidden = true
            emptyView.isHidden = false
            rListContainer.backgroundColor = GTTColor.white
            rListHeightConstraint?.update(offset: 180)
        } else {
            tableView.isHidden = false
            emptyView.isHidden = true
            rListContainer.backgroundColor = .clear
            let targetHeight = min(CGFloat(items.count) * 65, 260)
            rListHeightConstraint?.update(offset: targetHeight)
            tableView.reloadData()
        }

        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
    }

    private func updateMapPreview(coord: NMGLatLng?) {
        if let coord {
            customMapView?.removeFromSuperview()
            let newMapView = CustomNMView(coord: coord, isInteractive: true)
            mapPreviewContainer.addSubview(newMapView)
            newMapView.snp.makeConstraints { $0.edges.equalToSuperview() }
            customMapView = newMapView

            mapPreviewContainer.isHidden = false
            mapPreviewHeightConstraint?.update(offset: 160)
        } else {
            customMapView?.removeFromSuperview()
            customMapView = nil
            mapPreviewContainer.isHidden = true
            mapPreviewHeightConstraint?.update(offset: 0)
        }
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
    }

    // MARK: - Keyboard

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let info = n.userInfo,
              let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        let frameInView = view.convert(frame, from: nil)
        let offset = max(view.bounds.maxY - frameInView.minY - view.safeAreaInsets.bottom, 24)
        ctaBottomConstraint?.update(inset: offset)
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        guard let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        ctaBottomConstraint?.update(inset: 24)
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }
}

// MARK: - UITableViewDataSource / Delegate

extension LocationSelectViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        currentItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationResultCell", for: indexPath) as! LocationResultCell
        let item = currentItems[indexPath.row]
        let isLast = indexPath.row == currentItems.count - 1
        cell.configure(with: item, isSelected: currentSelectedIndex == indexPath.row, isLast: isLast)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        view.endEditing(true)
        tableView.deselectRow(at: indexPath, animated: false)
        itemTappedSubject.onNext(indexPath.row)
    }
}

// MARK: - LocationResultCell

final class LocationResultCell: UITableViewCell {
    static let identifier = "LocationResultCell"

    private let containerView = UIView()
    private let iconBox       = UIView()
    private let iconView      = UIImageView()
    private let nameLabel     = UILabel()
    private let addressLabel  = UILabel()
    private let dividerView   = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        containerView.backgroundColor = .clear
        containerView.layer.borderWidth = 0
        containerView.layer.cornerRadius = 0
        iconBox.backgroundColor = GTTColor.bgCard
        iconView.tintColor = GTTColor.textSecondary
        dividerView.isHidden = false
    }

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(containerView)
        containerView.addSubview(iconBox)
        iconBox.addSubview(iconView)

        let infoStack = UIStackView(arrangedSubviews: [nameLabel, addressLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 2
        containerView.addSubview(infoStack)
        
        contentView.addSubview(dividerView)

        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }

        iconBox.layer.cornerRadius = 10
        iconBox.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(36)
        }

        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage(systemName: "mappin.and.ellipse")
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(18)
        }

        infoStack.snp.makeConstraints { make in
            make.leading.equalTo(iconBox.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(16)
            make.top.bottom.equalToSuperview().inset(14)
        }

        nameLabel.font = GTTFont.placeName.font
        nameLabel.textColor = GTTColor.textPrimary
        addressLabel.font = GTTFont.badge.font
        addressLabel.textColor = GTTColor.textQuiet
        
        dividerView.backgroundColor = GTTColor.divider
        dividerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    func configure(with item: NaverLocalItem, isSelected: Bool, isLast: Bool) {
        nameLabel.text = item.cleanTitle
        addressLabel.text = item.roadAddress.isEmpty ? item.address : item.roadAddress

        if isSelected {
            containerView.backgroundColor = GTTColor.bgCard
            containerView.layer.borderColor = GTTColor.brand.cgColor
            containerView.layer.borderWidth = 1.5
            containerView.layer.cornerRadius = 12
            containerView.clipsToBounds = true
            iconBox.backgroundColor = GTTColor.brand
            iconView.tintColor = GTTColor.white
            dividerView.isHidden = true
        } else {
            containerView.backgroundColor = .clear
            containerView.layer.borderWidth = 0
            containerView.layer.cornerRadius = 0
            iconBox.backgroundColor = GTTColor.bgCard
            iconView.tintColor = GTTColor.textSecondary
            dividerView.isHidden = isLast
        }
    }
}
