// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import FirebaseRemoteConfig
import FirebaseCore

class RemoteConfigViewController: UIViewController {
  private var remoteConfig: RemoteConfig!
  private var remoteConfigView: RemoteConfigView { view as! RemoteConfigView }

  private let topLabelKey = "topLabelKey"
  private let typedRecipeKey = "typedRecipeKey"
  private let bottomLabelKey = "bottomLabelKey"

  override func loadView() {
    view = RemoteConfigView()
  }

  /// Convenience init for injecting Remote Config instances during testing
  /// - Parameter remoteConfig: a Remote Config instance
  convenience init(remoteConfig: RemoteConfig) {
    self.init()
    self.remoteConfig = remoteConfig
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    configureNavigationBar()
    setupRemoteConfig()
    configureFetchButtonAction()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  //  fetchAndActivateRemoteConfig()
  }

  // MARK: - Firebase 🔥

  // Add additional keys that are in the console to see them in the log after fetching the config.
  struct QSConfig: Codable {
    let topLabelKey: String
    let bottomLabelKey: String
    let freeCount: Int
  }

  /// Initializes defaults from `RemoteConfigDefaults.plist` and sets config's settings to developer mode
  private func setupRemoteConfig() {
    
    //issue #16354
    guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
     let options = FirebaseOptions(contentsOfFile: plistPath) else {
          fatalError("Could not locate or load the secondary Firebase plist file.")
      }
      
    FirebaseApp.configure(name: "ConfigExample", options: options)

    let app = FirebaseApp.app(name: "ConfigExample")!
    let remoteConfig = RemoteConfig.remoteConfig(app: app)
      
    remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults")
    // This is an alternative to remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults"))
     // do {
          // try remoteConfig.setDefaults(from: QSConfig(topLabelKey: "myTopLabel",
          //                                             bottomLabelKey: "Buy one get one free!",
          //                                             freeCount: 4))
     // } catch {
     // print("Failed to set Defaults.")
    //}
    let settings = RemoteConfigSettings()
    settings.minimumFetchInterval = 0
    remoteConfig.configSettings = settings
      
      //issue #16354
      Task {
          do {
              // 1. Fetch values safely
              let status = try await remoteConfig.fetch()
              // 2. Activate the fetched parameters
              let activated = try await remoteConfig.activate()
              print("Fetch succeeded with status: \(status) : \(activated)")
          } catch {
              // 3. Fallback gracefully when errors are intercepted
              print("Failed to fetch Remote Config: \(error.localizedDescription)")
              // Your app will automatically fall back to its configured local defaults here
          }
      }
      
      
    // [START add_config_update_listener]
    remoteConfig.addOnConfigUpdateListener { configUpdate, error in
      guard error == nil else { return self.displayError(error) }
      print("Updated keys: \(configUpdate!.updatedKeys)")
    }
    // [END add_config_update_listener]
  }

  /// Fetches and activates remote config values
  @objc
  private func fetchAndActivateRemoteConfig() {
     
      remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults")
      
      DispatchQueue.global(qos: .utility).async {
          self.remoteConfig.fetchAndActivate { status, error in
              print("Remote config successfully fetched: \(status.rawValue)")
          }
      }
      
      
    /** remoteConfig.fetchAndActivate { status, error in
      guard error == nil else { return self.displayError(error) }
      print("Remote config successfully fetched & activated!")
      do {
        let qsConfig: QSConfig = try self.remoteConfig.decoded()
        print(qsConfig)
      } catch {
        self.displayError(error)
        return
      }
      DispatchQueue.main.async {
        self.updateUI()
      }
    } */
  }

  /// This method applies our remote config values to our UI
  private func updateUI() {
    remoteConfigView.topLabel.text = remoteConfig[decodedValue: "topLabelKey"]
    updateJSONView()
    if var bottomLabel: String = remoteConfig[decodedValue: "bottomLabelKey"] {
      if let freeCount: Int = remoteConfig[decodedValue: "freeCount"],
        freeCount > 1,
        bottomLabel.contains("one") {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        if let english = formatter.string(from: NSNumber(value: freeCount)) {
          bottomLabel = bottomLabel.replacingOccurrences(of: "one free", with: "\(english) free")
        }
      }
      remoteConfigView.bottomLabel.text = bottomLabel
    }
  }

  // MARK: - Private Helpers

  private func configureNavigationBar() {
    navigationItem.title = "Firebase Config"
    guard let navigationBar = navigationController?.navigationBar else { return }
    navigationBar.prefersLargeTitles = true
    navigationBar.titleTextAttributes = [.foregroundColor: UIColor.systemOrange]
    navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.systemOrange]
  }

  private func configureFetchButtonAction() {
    remoteConfigView.fetchButton.addTarget(
      self,
      action: #selector(fetchAndActivateRemoteConfig),
      for: .touchUpInside
    )
  }

  private func updateJSONView() {
    let jsonView = remoteConfigView.jsonView!
    let displayedJSON = jsonView.subviews
    displayedJSON.forEach { label in
      UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
        label.alpha = 0
      }) { _ in
        label.removeFromSuperview()
      }
    }

    struct Recipe: Decodable, CustomStringConvertible {
      var recipe_name: String
      var ingredients: [String]
      var prep_time: Int
      var cook_time: Int
      var instructions: [String]
      var yield: String
      var serving_size: Int
      var notes: String

      var description: String {
        return "Recipe Name: \(recipe_name)\n" +
          "Ingredients: \(ingredients)\n" +
          "Prep Time: \(prep_time)\n" +
          "Cook Time: \(cook_time)\n" +
          "Instructions: \(instructions)\n" +
          "Yield: \(yield)\n" +
          "Serving Size: \(serving_size)\n" +
          "Notes: \(notes)"
      }
    }

    guard let recipe: Recipe = try? remoteConfig[typedRecipeKey].decoded() else {
      print("Failed to decode JSON for \(typedRecipeKey)")
      return
    }
    let lines = recipe.description.split(separator: "\n")
    for (index, line) in lines.enumerated() {
      let lineSplit = line.split(separator: ":")
      let formattedKey = String(lineSplit[0])
      let stringValue = String(lineSplit[1])

      let attributedKey = NSAttributedString(
        string: formattedKey,
        attributes: [.foregroundColor: UIColor.secondaryLabel]
      )
      let attributedValue = NSAttributedString(
        string: stringValue,
        attributes: [.foregroundColor: UIColor.systemOrange]
      )
      let labelAttributedText = NSMutableAttributedString()
      labelAttributedText.append(attributedKey)
      labelAttributedText.append(attributedValue)

      let label = UILabel()
      label.attributedText = labelAttributedText
      label.alpha = 0
      label.sizeToFit()
      jsonView.addSubview(label)
      animateFadeIn(for: label, duration: 0.3)

      let height = jsonView.frame.height
      let step = height / CGFloat(lines.count)
      let offset = height * 0.2 * 1 / CGFloat(lines.count)

      let x: CGFloat = jsonView.frame.width * 0.05
      let y: CGFloat = step * CGFloat(index) + offset

      label.frame.origin = CGPoint(x: x, y: y)
    }
  }

  private func animateFadeIn(for view: UIView, duration: TimeInterval) {
    UIView.animate(withDuration: duration, delay: 0, options: .curveEaseIn, animations: {
      view.alpha = 1
    })
  }
}

extension UIViewController {
  public func displayError(_ error: Error?, from function: StaticString = #function) {
    guard let error = error else { return }
    print("🚨 Error in \(function): \(error.localizedDescription)")
    let message = "\(error.localizedDescription)\n\n Occurred in \(function)"
    let errorAlertController = UIAlertController(
      title: "Error",
      message: message,
      preferredStyle: .alert
    )
    errorAlertController.addAction(UIAlertAction(title: "OK", style: .default))
    DispatchQueue.main.async {
      self.present(errorAlertController, animated: true, completion: nil)
    }
  }
}
