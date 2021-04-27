import ReactiveSwift

extension Store {
  /// Calls one of two closures depending on whether a store's optional state is `nil` or not, and
  /// whenever this condition changes for as long as the cancellable lives.
  ///
  /// If the store's state is non-`nil`, it will safely unwrap the value and bundle it into a new
  /// store of non-optional state that is passed to the first closure. If the store's state is
  /// `nil`, the second closure is called instead.
  ///
  /// This method is useful for handling navigation in UIKit. The state for a screen the user wants
  /// to navigate to can be held as an optional value in the parent, and when that value goes from
  /// `nil` to non-`nil`, or non-`nil` to `nil`, you can update the navigation stack accordingly:
  ///
  ///     class ParentViewController: UIViewController {
  ///       let store: Store<ParentState, ParentAction>
  ///       ...
  ///       func viewDidLoad() {
  ///         ...
  ///         self.store
  ///           .scope(state: \.optionalChild, action: ParentAction.child)
  ///           .ifLet(
  ///             then: { [weak self] childStore in
  ///               self?.navigationController?.pushViewController(
  ///                 ChildViewController(store: childStore),
  ///                 animated: true
  ///               )
  ///             },
  ///             else: { [weak self] in
  ///               guard let self = self else { return }
  ///               self.navigationController?.popToViewController(self, animated: true)
  ///             }
  ///           )
  ///       }
  ///     }
  ///
  /// - Parameters:
  ///   - unwrap: A function that is called with a store of non-optional state when the store's
  ///     state is non-`nil`, or whenever it goes from `nil` to non-`nil`.
  ///   - else: A function that is called when the store's optional state is `nil`, or whenever it
  ///     goes from non-`nil` to `nil`.
  /// - Returns: A disposable that maintains a subscription to updates whenever the store's state
  ///   goes from `nil` to non-`nil` and vice versa, so that the caller can react to these changes.
  @discardableResult
  public func ifLet<Wrapped>(
    then unwrap: @escaping (Store<Wrapped, Action>) -> Void,
    else: @escaping () -> Void = {}
  ) -> Disposable where State == Wrapped? {
    let elseDisposable =
      self
      .producerScope(
        state: { state -> Effect<Wrapped?, Never> in
          state
            .skipRepeats { ($0 != nil) == ($1 != nil) }
        }
      )
      .startWithValues { store in
        if store.state == nil { `else`() }
      }

    let unwrapDisposable =
      self
      .producerScope(
        state: { state -> Effect<Wrapped, Never> in
          state
            .skipRepeats { ($0 != nil) == ($1 != nil) }
            .compactMap { $0 }
        }
      )
      .startWithValues(unwrap)

    return CompositeDisposable([elseDisposable, unwrapDisposable])
  }
}
