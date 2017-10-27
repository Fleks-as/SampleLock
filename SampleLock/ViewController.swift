//
//  ViewController.swift
//  SampleLock
//
//  Created by August Z. Flatby on 24/10/2017.
//  Copyright © 2017 August Z. Flatby. All rights reserved.
//

import UIKit
import AudioToolbox
import RMQClient
import pop

class ViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var pinBack: UIView!
    @IBOutlet weak var lockView: UIImageView!
    @IBOutlet weak var pinLabel: UILabel!
    @IBOutlet var accessoryView: UIView!
    @IBOutlet weak var logView: UITextView!
    
    var isLocked: Bool = true {
        didSet {
            if oldValue != isLocked {
                isLocked ? lock() : unlock()
            }
        }
    }

    var conn: RMQConnection!
    var exchange: RMQExchange!
    var pin = "NO PIN"
    var lockID = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pinBack.layer.cornerRadius = 5
                textField.becomeFirstResponder()
        textField.delegate = self
        textField.autocorrectionType = .no
        textField.inputAccessoryView = accessoryView
        amqpConn()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        conn?.close()
    }

    func log(_ msg: String) {
        DispatchQueue.main.async {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss"
            let now = dateFormatter.string(from: Date())
            
            self.logView.text = "\(self.logView.text!)\n[\(now)] \(msg)"
            let margins: CGFloat = 6
            let tvHeight = self.logView.frame.height + margins
            let size = self.logView.sizeThatFits(CGSize(width: self.logView.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
            self.logView.setContentOffset(CGPoint(x:0, y:size.height - tvHeight), animated: true)
        }
    }
    
    func createAmqpTopography() {
        
    }
    
    func amqpConn() {
        lockID = UIDevice.current.identifierForVendor!.uuidString.components(separatedBy: "-").first!
        log("Lock ID: \(lockID)")
        
        log("Connecting to message broker...")
        guard let uri = ProcessInfo.processInfo.environment["AMQP_URL"] else {
            log("FATAL! Missing env var: AMQP_URL")
            return
        }
        
        let delegate = RMQConnectionDelegateLogger()
        conn = RMQConnection(uri: uri, delegate: delegate)
        conn.start {
            self.log("Connected")
        }
        
        let amqpCh = conn.createChannel()
        exchange = amqpCh.topic("sample-lock.x")
        
        // queue for remove pincode commands
        let removeKey = "remove.\(lockID)"
        let removeQ = amqpCh.queue(removeKey, options: .exclusive)
        removeQ.bind(exchange, routingKey: removeKey)
        removeQ.subscribe({ pin in
            self.pin = "NO PIN"
            self.log("Remove current pin")
            DispatchQueue.main.async {
                self.highlight("")
            }
        })
        
        // queue for add pincode commands
        let addKey = "add.\(lockID)"
        let addQ = amqpCh.queue(addKey, options: .exclusive)
        addQ.bind(exchange, routingKey: addKey)
        addQ.subscribe({ pin in
            self.pin = String(data: pin.body, encoding: String.Encoding.utf8)!
            self.log("Received new pin: \(self.pin)")
            DispatchQueue.main.async {
                self.highlight("")
            }
        })
        
        // start with a sample pincode
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.log("Adding dummy pincode")
            self.exchange.publish("223344".data(using: String.Encoding.utf8), routingKey: "add.\(self.lockID)")
        }
    }
    
    func unlock() {
        log("Unlock with \(pin)")
        play("unlock")
        lockView.image = #imageLiteral(resourceName: "unlock")
        addPop(lockView)
        exchange.publish("unlocked".data(using: String.Encoding.utf8), routingKey: "state.\(lockID)")
    }
    
    func lock() {
        log("Lock")
        play("lock")
        lockView.image = #imageLiteral(resourceName: "lock")
        addPop(lockView)
        exchange.publish("locked".data(using: String.Encoding.utf8), routingKey: "state.\(lockID)")
    }
    
    func play(_ filename: String) {
        let ext = "wav"
        
        if let soundUrl = Bundle.main.url(forResource: filename, withExtension: ext) {
            var soundId: SystemSoundID = 0
            
            AudioServicesCreateSystemSoundID(soundUrl as CFURL, &soundId)
            
            AudioServicesAddSystemSoundCompletion(soundId, nil, nil, { (soundId, clientData) -> Void in
                AudioServicesDisposeSystemSoundID(soundId)
            }, nil)
            
            AudioServicesPlaySystemSound(soundId)
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if range.length > 0 {
            // ignore delete button
            return false
        }
        return checkPin(textField.text! + string)
    }
    
    func checkPin(_ enteredText: String) -> Bool {
        if enteredText == pin {
            highlight(enteredText)
            isLocked = false
        }
        else if pin.hasPrefix(enteredText) {
            highlight(enteredText)
            return true
        }
        else {
            isLocked = true
            highlight("")
        }
        textField.text = ""
        return false
    }

    func highlight(_ enteredText: String) {
        let end = enteredText.endIndex
        let remainingText = pin[end...]
        let attrFront = [NSAttributedStringKey.foregroundColor: UIColor.black]
        let attrBack = [NSAttributedStringKey.foregroundColor: UIColor.lightGray]
        let pre = NSMutableAttributedString(string: enteredText, attributes: attrFront)
        let post = NSMutableAttributedString(string: String(remainingText), attributes: attrBack)
        pre.append(post)
        pinLabel.attributedText = pre
    }
    
    private func addPop(_ view: UIView) {
        let spring = POPSpringAnimation(propertyNamed: kPOPViewScaleXY)!
        spring.velocity = NSValue(cgPoint: CGPoint(x: 15, y: 15))
        view.pop_removeAnimation(forKey: "key")
        view.pop_add(spring, forKey: "key")
    }
}
