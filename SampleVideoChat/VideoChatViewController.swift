//
//  VideoChatViewController.swift
//  SampleVideoChat
//
//  Created by Akihiro Sakahara on 2021/02/09.
//

import UIKit
import OpenTok

// PROJECT API KEY を設定します
private let kApiKey = ""
// 生成されたsession IDを設定します
private let kSessionId = ""
// 生成されたTokenを設定します
private let kToken = ""

class VideoChatViewController: UIViewController {
    private lazy var session: OTSession? = {
        OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)
    }()

    private lazy var publisher: OTPublisher? = {
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        return OTPublisher(delegate: self, settings: settings)
    }()

    var subscriber: OTSubscriber?

    override func viewDidLoad() {
        super.viewDidLoad()

        connect()
    }

    /**
     * セッションへの接続を開始します
     */
    private func connect() {
        var error: OTError?
        defer { showError(error) }
        session?.connect(withToken: kToken, error: &error)
    }

    /**
     * セッションへの接続完了後に、カメラの映像とマイクの音声をセッションに発行します。
     * 発行するカメラ映像をViewに表示します。
     */
    private func publish() {
        guard let publisher = publisher else { return }

        var error: OTError?
        defer { showError(error) }

        session?.publish(publisher, error: &error)

        if let publisherView = publisher.view {
            publisherView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(publisherView)

            // 自分のカメラ映像を左隅に表示します。
            publisherView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60).isActive = true
            publisherView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20).isActive = true
            publisherView.widthAnchor.constraint(equalToConstant: 100).isActive = true
            publisherView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        }
    }

    /**
     * セッションに接続した他のユーザーが発行したデータはストリームとして流れてきます。
     * このストリームを元にSubscriberを生成し、購読することで映像と音声を受け取ることができます。
     */
    private func subscribe(_ stream: OTStream) {
        var error: OTError?
        defer { showError(error) }
        subscriber = OTSubscriber(stream: stream, delegate: self)
        session?.subscribe(subscriber!, error: &error)
    }

    private func cleanupSubscriber() {
        subscriber?.view?.removeFromSuperview()
        subscriber = nil
    }

    private func cleanupPublisher() {
        publisher?.view?.removeFromSuperview()
    }

    private func showError(_ error: OTError?) {
        guard let error = error else { return }
        DispatchQueue.main.async { [weak self] in
            let controller = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self?.present(controller, animated: true, completion: nil)
        }
    }
}

extension VideoChatViewController: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        // publisherの生成と発行処理
        publish()
    }

    func sessionDidDisconnect(_ session: OTSession) {}

    func session(_ session: OTSession, streamCreated stream: OTStream) {
        if subscriber == nil {
            // 購読処理を開始する
            subscribe(stream)
        }
    }

    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            // ストリームが破棄されたらsubscriberの初期化を行う
            cleanupSubscriber()
        }
    }

    func session(_ session: OTSession, didFailWithError error: OTError) {
        showError(error)
    }
}

extension VideoChatViewController: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {}

    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        cleanupPublisher()
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }

    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {}
}

extension VideoChatViewController: OTSubscriberDelegate {
    /**
     * Subscriberの接続が完了したタイミングで、Subscriberが持つViewプロパティを追加して送られてくる映像を表示する
     */
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        guard let subscriberView = subscriber?.view else { return }
        subscriberView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subscriberView)
        view.sendSubviewToBack(subscriberView)

        // 相手のカメラ映像を画面全体に表示します。
        subscriberView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        subscriberView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        subscriberView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        subscriberView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }

    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        showError(error)
    }
}
