import UIKit

extension UILabel {

  /**
   Turn this option on in IB to have the value of the label cleared on initialization.
  */
  @IBInspectable
  var clearIBValue: Bool {
    set(clear) {
      if clear {
        self.text = ""
      }
    }
    get {
      return false
    }
  }
}