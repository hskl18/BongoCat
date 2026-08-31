import Foundation
import GameController

@MainActor
final class GamepadMonitor: NSObject {
    var onInput: ((GamepadInput, Double) -> Void)?
    var onDisconnect: (() -> Void)?

    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true
        GCController.shouldMonitorBackgroundEvents = true
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(controllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(controllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )
        GCController.controllers().forEach(configure)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        NotificationCenter.default.removeObserver(self)
        onDisconnect?()
    }

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        configure(controller)
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        onDisconnect?()
    }

    private func configure(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        bind(gamepad.buttonA, to: .south)
        bind(gamepad.buttonB, to: .east)
        bind(gamepad.buttonX, to: .west)
        bind(gamepad.buttonY, to: .north)
        bind(gamepad.leftShoulder, to: .leftShoulder)
        bind(gamepad.leftTrigger, to: .leftTrigger)
        bind(gamepad.rightShoulder, to: .rightShoulder)
        bind(gamepad.rightTrigger, to: .rightTrigger)
        bind(gamepad.dpad.up, to: .dPadUp)
        bind(gamepad.dpad.down, to: .dPadDown)
        bind(gamepad.dpad.left, to: .dPadLeft)
        bind(gamepad.dpad.right, to: .dPadRight)
        if let button = gamepad.leftThumbstickButton {
            bind(button, to: .leftThumb)
        }
        if let button = gamepad.rightThumbstickButton {
            bind(button, to: .rightThumb)
        }
        bind(gamepad.leftThumbstick.xAxis, to: .leftStickX)
        bind(gamepad.leftThumbstick.yAxis, to: .leftStickY)
        bind(gamepad.rightThumbstick.xAxis, to: .rightStickX)
        bind(gamepad.rightThumbstick.yAxis, to: .rightStickY)
    }

    private func bind(_ button: GCControllerButtonInput, to input: GamepadInput) {
        button.valueChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.onInput?(input, pressed ? Double(value) : 0)
            }
        }
    }

    private func bind(_ axis: GCControllerAxisInput, to input: GamepadInput) {
        axis.valueChangedHandler = { [weak self] _, value in
            Task { @MainActor in
                self?.onInput?(input, Double(value))
            }
        }
    }
}
