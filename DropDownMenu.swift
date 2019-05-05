/**
	Copyright (C) 2015 Quentin Mathe
 
	Date:  May 2015
	License:  MIT
 */

import UIKit

@objc public protocol DropDownMenuDelegate {
	func didTapInDropDownMenuBackground(_ menu: DropDownMenu)
}

public enum DropDownMenuRevealDirection {
	case up
	case down
}


open class DropDownMenu : UIView, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {

	open weak var delegate: DropDownMenuDelegate?
	open weak var container: UIView? {
		didSet {
			removeFromSuperview()
			container?.addSubview(self)
		}
	}
	// The content view fills the entire container, so we can use it to fade 
	// the background view in and out.
	//
	// By default, it contains the menu view, but other subviews can be added to 
	// it and laid out by overriding -layoutSubviews.
	public let contentView = UIView(frame: .zero)
	// This hidden insets can be used to customize the position of the menu at
	// the end of the hiding animation.
	//
	// If the container doesn't extend under the toolbar and navigation bar,
	// this is useful to ensure the hiding animation continues until the menu is
	// positioned outside of the screen, rather than stopping the animation when 
	// the menu is covered by the toolbar or navigation bar.
	//
	// Left and right insets are currently ignored.
	open var hiddenContentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) {
		didSet {
			setNeedsLayout()
		}
	}
	// This visible insets can be used to customize the position of the menu
	// at the end of the showing animation.
	//
	// If the container extends under the toolbar and navigation bar, this is 
	// useful to ensure the menu won't be covered by the toolbar or navigation 
	// bar once the showing animation is done.
	//
	// Left and right insets are currently ignored.
	open var visibleContentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) {
		didSet {
			// Menu height needs to be recomputed
			setNeedsLayout()
		}
	}
	open var direction = DropDownMenuRevealDirection.down {
		didSet {
			setNeedsLayout()
		}
	}
	public let menuView = UITableView(frame: .zero)
	open var menuCells = [DropDownMenuCell]() {
		didSet {
			menuView.reloadData()
			setNeedsLayout()
		}
	}
	// The background view to be faded out with the background alpha, when the 
	// menu slides over it
	open var backgroundView: UIView? {
		didSet {
			oldValue?.removeFromSuperview()
			backgroundView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
			backgroundView?.alpha = oldValue?.alpha ?? 0
			if let backgroundView = backgroundView {
				insertSubview(backgroundView, belowSubview: contentView)
			}
		}
	}
	open var backgroundAlpha = CGFloat(1)

	// MARK: - Initialization

	override public init(frame: CGRect) {
		super.init(frame: frame)
		setUp()
	}

	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}

	open override func awakeFromNib() {
		setUp()
	}

	private func setUp() {
		menuView.frame.size = frame.size
		menuView.autoresizingMask = .flexibleWidth
		menuView.isScrollEnabled = true
		menuView.bounces = false
		menuView.showsVerticalScrollIndicator = true
		menuView.showsHorizontalScrollIndicator = false
		menuView.dataSource = self
		menuView.delegate = self

		contentView.frame.size = frame.size
		contentView.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
		contentView.addSubview(menuView)

		let gesture = UITapGestureRecognizer(target: self, action: #selector(DropDownMenu.tap(_:)))
		gesture.delegate = self

		addGestureRecognizer(gesture)
		autoresizingMask = [.flexibleWidth, .flexibleHeight]
		isHidden = true
		addSubview(contentView)
	}
	
	// MARK: - Layout

	private enum LayoutOperation {
		case show
		case hide
	}

	private func updateContentViewPosition(on operation: LayoutOperation) {
		guard let container = container else {
			fatalError("DropDownMenu.container must have been set to layout subviews")
		}
		switch (operation, direction) {
		case (.hide, .down):
			contentView.frame.origin.y = hiddenContentInsets.top - contentView.frame.height
		case (.hide, .up):
			contentView.frame.origin.y = container.frame.height - hiddenContentInsets.bottom
		case (.show, .down):
			contentView.frame.origin.y = visibleContentInsets.top
		case (.show, .up):
			contentView.frame.origin.y = container.frame.height - contentView.frame.height - visibleContentInsets.bottom
		}
	}
	
	open override func layoutSubviews() {
		super.layoutSubviews()

		let contentHeight = menuCells.reduce(0) { $0 + $1.rowHeight }
		let maxContentHeight = frame.height - visibleContentInsets.bottom - visibleContentInsets.top
		let scrollable = contentHeight > maxContentHeight

		menuView.frame.size.height = scrollable ? maxContentHeight : contentHeight
		contentView.frame.size.height = menuView.frame.height
		updateContentViewPosition(on: isHidden ? .hide : .show)

		// Reset scroll view content offset after rotation
		if menuView.visibleCells.isEmpty {
			return
		}
		menuView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
	}
	
	// MARK: - Selection
	
	/// Selects the cell briefly and sends the cell menu action.
	///
	/// If DropDownMenuCell.showsCheckmark is true, then the cell is marked with
	/// a checkmark and all other cells are unchecked.
	open func selectMenuCell(_ cell: DropDownMenuCell) {
		guard let index = menuCells.firstIndex(of: cell) else {
			fatalError("The menu cell to select must belong to the menu")
		}
		let indexPath = IndexPath(row: index, section: 0)

		menuView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
		tableView(menuView, didSelectRowAt: indexPath)
	}

	// MARK: - Actions
	
	@IBAction open func tap(_ sender: AnyObject) {
		delegate?.didTapInDropDownMenuBackground(self)
	}
	
	// If we declare a protocol method private, it is not called anymore.
	open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		precondition(gestureRecognizer.view == self)

		guard let touchedView = touch.view else {
			return true
		}
		return !touchedView.isDescendant(of: menuView)
	}
	
	@IBAction open func show() {
		if !isHidden {
			return
		}
		isHidden = false

		UIView.animate(withDuration: 0.4,
		                      delay: 0,
		     usingSpringWithDamping: 1,
		      initialSpringVelocity: 1,
		                    options: UIView.AnimationOptions(),
		                 animations: {
			self.updateContentViewPosition(on: .show)
			self.backgroundView?.alpha = self.backgroundAlpha
		},
		                 completion: nil)
	}
	
	@IBAction open func hide() {
		if isHidden {
			return
		}

		UIView.animate(withDuration: 0.4,
		                      delay: 0,
		     usingSpringWithDamping: 1,
		      initialSpringVelocity: 1,
		                    options: UIView.AnimationOptions(),
		                 animations: {
			self.updateContentViewPosition(on: .hide)
			self.backgroundView?.alpha = 0
		},
				       completion: { (Bool) in
			self.isHidden = true
		})
	}
	
	// MARK: - Table View
	
	open func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return menuCells.count
	}

	open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return menuCells[indexPath.row].rowHeight
	}

	open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return menuCells[indexPath.row]
	}
	
	open func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
		return menuCells[indexPath.row].menuAction != nil
	}

	open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let cell = menuCells[indexPath.row]
		
		for cell in menuCells {
			cell.accessoryType = .none
		}
		cell.accessoryType = cell.showsCheckmark ? .checkmark : .none
		
		tableView.deselectRow(at: indexPath, animated: true)
		
		guard let menuAction = cell.menuAction else {
			return
		}

		#if APP_EXTENSION
			guard let menuTarget = cell.menuTarget, menuTarget.responds(to: menuAction) else {
				return
			}
			_ = menuTarget.perform(menuAction, with: cell)
		#else
			UIApplication.shared.sendAction(menuAction, to: cell.menuTarget, from: cell, for: nil)
		#endif
	}
}
