import KsApi
import Prelude
import ReactiveCocoa
import ReactiveExtensions
import Result

public protocol ProjectActivityBackingCellViewModelInputs {
  /// Call when the backing info button is pressed.
  func backingInfoButtonPressed()

  /// Call to set the activity.
  func configureWith(activity activity: Activity)

  /// Call when the send message button is pressed.
  func sendMessageButtonPressed()
}

public protocol ProjectActivityBackingCellViewModelOutputs {
  /// Emits a URL for the backer's avatar.
  var backerImageURL: Signal<NSURL?, NoError> { get }

  /// Emits when the backing info screen should be loaded.
  var goToBackingInfo: Signal<Backing, NoError> { get }

  /// Emits when the send message screen should be loaded.
  var goToSendMessage: Signal<(Project, Backing), NoError> { get }

  /// Emits the new pledge amount.
  var pledgeAmount: Signal<String, NoError> { get }

  /// Emits whether the pledge amount label should be hidden.
  var pledgeAmountLabelIsHidden: Signal<Bool, NoError> { get }

  /// Emits the old pledge amount.
  var previousPledgeAmount: Signal<String, NoError> { get }

  /// Emits whether the previous pledge amount label should be hidden.
  var previousPledgeAmountLabelIsHidden: Signal<Bool, NoError> { get }

  /// Emits a description of the reward.
  var reward: Signal<String, NoError> { get }

  /// Emits the activity's title.
  var title: Signal<String, NoError> { get }
}

public protocol ProjectActivityBackingCellViewModelType {
  var inputs: ProjectActivityBackingCellViewModelInputs { get }
  var outputs: ProjectActivityBackingCellViewModelOutputs { get }
}

public final class ProjectActivityBackingCellViewModel: ProjectActivityBackingCellViewModelType,
ProjectActivityBackingCellViewModelInputs, ProjectActivityBackingCellViewModelOutputs {

  public init() {
    let activity = self.activityProperty.signal.ignoreNil()

    self.backerImageURL = activity
      .map { ($0.user?.avatar.medium).flatMap(NSURL.init) }

    self.goToBackingInfo = activity
      .takeWhen(self.backingInfoButtonPressedProperty.signal)
      .map { $0.memberData.backing }
      .ignoreNil()

    self.goToSendMessage = activity
      .map { activity -> (Project, Backing)? in
        guard let project = activity.project else { return nil }
        guard let backing = activity.memberData.backing else { return nil }
        return (project, backing)
      }
      .ignoreNil()

    self.pledgeAmount = activity.map { activity in
      guard let amount = activity.memberData.amount ?? activity.memberData.newAmount else { return "" }
      guard let country = activity.project?.country else { return "" }

      return Format.currency(amount, country: country)
    }

    self.pledgeAmountLabelIsHidden = self.pledgeAmount
      .map { $0.isEmpty }
      .skipRepeats()

    self.previousPledgeAmount = activity.map { activity in
      guard let amount = activity.memberData.oldAmount else { return "" }
      guard let country = activity.project?.country else { return "" }

      return Format.currency(amount, country: country)
    }

    self.previousPledgeAmountLabelIsHidden = self.previousPledgeAmount
      .map { $0.isEmpty }
      .skipRepeats()

    self.reward = activity.map(rewardSummary(fromActivity:))

    self.title = activity.map(title(fromActivity:))
  }

  private let backingInfoButtonPressedProperty = MutableProperty()
  public func backingInfoButtonPressed() {
    self.backingInfoButtonPressedProperty.value = ()
  }

  private let activityProperty = MutableProperty<Activity?>(nil)
  public func configureWith(activity activity: Activity) {
    self.activityProperty.value = activity
  }

  private let sendMessageButtonPressedProperty = MutableProperty()
  public func sendMessageButtonPressed() {
    self.sendMessageButtonPressedProperty.value = ()
  }

  public let backerImageURL: Signal<NSURL?, NoError>
  public let goToBackingInfo: Signal<Backing, NoError>
  public let goToSendMessage: Signal<(Project, Backing), NoError>
  public let pledgeAmount: Signal<String, NoError>
  public let pledgeAmountLabelIsHidden: Signal<Bool, NoError>
  public let previousPledgeAmount: Signal<String, NoError>
  public let previousPledgeAmountLabelIsHidden: Signal<Bool, NoError>
  public let reward: Signal<String, NoError>
  public let title: Signal<String, NoError>

  public var inputs: ProjectActivityBackingCellViewModelInputs { return self }
  public var outputs: ProjectActivityBackingCellViewModelOutputs { return self }
}

private func currentUserIsBacker(activity activity: Activity) -> Bool {
  guard let backing = activity.memberData.backing else { return false }
  return AppEnvironment.current.currentUser?.id == backing.backerId
}

private func rewardSummary(fromActivity activity: Activity) -> String {
  guard let reward = reward(fromActivity: activity) else { return "" }
  return reward.title ?? reward.description
}

private func reward(fromActivity activity: Activity) -> Reward? {
  guard let rewardId = activity.memberData.rewardId ?? activity.memberData.newRewardId else { return nil }
  guard let rewards = activity.project?.rewards else { return nil }

  return rewards.filter { $0.id == rewardId }.first
}

private func title(fromActivity activity: Activity) -> String {
  guard let userName = activity.user?.name else { return "" }

  switch activity.category {
  case .backing:
    return currentUserIsBacker(activity: activity) ?
      Strings.activity_creator_actions_you_pledged() :
      Strings.activity_creator_actions_user_name_pledged(user_name: userName)
  case .backingAmount:
    return currentUserIsBacker(activity: activity) ?
      Strings.activity_creator_actions_you_adjusted_your_pledge() :
      Strings.activity_creator_actions_user_name_adjusted_their_pledge(user_name: userName)
  case .backingCanceled:
    return currentUserIsBacker(activity: activity) ?
      Strings.activity_creator_actions_you_canceled_your_pledge() :
      Strings.activity_creator_actions_user_name_canceled_their_pledge(user_name: userName)
  case .backingReward:
    return currentUserIsBacker(activity: activity) ?
      Strings.activity_creator_actions_you_changed_your_reward() :
      Strings.activity_creator_actions_user_name_changed_their_reward(user_name: userName)
  default:
    assertionFailure("Unrecognized activity: \(activity).")
    return ""
  }
}