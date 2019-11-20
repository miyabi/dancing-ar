//
//  ViewController.swift
//  DancingAR
//
//  Created by Masayuki Iwai on 2019/10/02.
//  Copyright © 2019 Masayuki Iwai. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Metal

class ViewController: UIViewController, ARSCNViewDelegate, ARCoachingOverlayViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var scaleLabel: UILabel!
    @IBOutlet weak var scaleSlider: UISlider!
    @IBOutlet weak var occlusionSwitch: UISwitch!
    
    var baseNode: SCNNode!
    var coachingOverlayView: ARCoachingOverlayView!
    var ambientLightNode: SCNNode!
    var directionalLightNode: SCNNode!
    
    let objectOffset = SCNVector3Make(0.0, 0.001, 0.0)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()

        // Set the scene to the view
        sceneView.scene = scene

        // Set up lights
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.shadowMode = .deferred
        ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)

        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 1000
        directionalLight.castsShadow = true
        directionalLight.shadowMode = .deferred
        directionalLight.shadowColor = UIColor.black.withAlphaComponent(0.5)
        directionalLight.shadowSampleCount = 8
        directionalLight.shadowRadius = 8
        directionalLightNode = SCNNode()
        directionalLightNode.light = directionalLight
        directionalLightNode.rotation = SCNVector4Make(1.0, 0.0, 0.0, -Float.pi / 2.0)
        scene.rootNode.addChildNode(directionalLightNode)

        // Load model
        baseNode = SCNScene(named: "Samba Dancing.dae")!.rootNode.childNode(withName: "Base", recursively: true)

        // Set up coaching overlay view
        coachingOverlayView = ARCoachingOverlayView()
        coachingOverlayView.session = sceneView.session
        coachingOverlayView.delegate = self
        coachingOverlayView.activatesAutomatically = true
        coachingOverlayView.goal = .horizontalPlane
        
        sceneView.addSubview(coachingOverlayView)

        coachingOverlayView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            coachingOverlayView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coachingOverlayView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            coachingOverlayView.widthAnchor.constraint(equalTo: view.widthAnchor),
            coachingOverlayView.heightAnchor.constraint(equalTo: view.heightAnchor),
        ])
        
        setScaleLabel(scaleSlider.value)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.isLightEstimationEnabled = true
        configuration.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            if occlusionSwitch.isOn {
                configuration.frameSemantics.insert(.personSegmentationWithDepth)
            }
        }

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        let device = MTLCreateSystemDefaultDevice()!
        let planeGeometry = ARSCNPlaneGeometry(device: device)!
        planeGeometry.update(from: planeAnchor.geometry)
        planeGeometry.firstMaterial?.colorBufferWriteMask = []
//        planeGeometry.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
        node.geometry = planeGeometry
    }
    
    func addObjectAt(_ position: SCNVector3) {
        let newBaseNode = baseNode.clone()

        let scale = 1.7 * scaleSlider.value
        newBaseNode.position = SCNVector3Make(
            position.x + objectOffset.x,
            position.y + objectOffset.y,
            position.z + objectOffset.z
        )
        newBaseNode.scale = SCNVector3Make(scale, scale, scale)
        sceneView.scene.rootNode.addChildNode(newBaseNode)
    }
    
    @IBAction func screenDidTap(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view else { return }
        
        if sender.state == .ended {
            let location = sender.location(in: view)
            guard let raycastQuery = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .horizontal) else { return }
            guard let raycastResult = sceneView.session.raycast(raycastQuery).first else { return }

            let position = SCNVector3Make(
                raycastResult.worldTransform.columns.3.x,
                raycastResult.worldTransform.columns.3.y,
                raycastResult.worldTransform.columns.3.z
            )
            addObjectAt(position)
        }
    }
    
    func setScaleLabel(_ scale: Float) {
        scaleLabel.text = "Scale: \(scale)"
    }

    @IBAction func scaleSliderValueDidChange(_ sender: UISlider) {
        let scale = floorf(sender.value * 10.0) / 10.0
        scaleSlider.value = scale
        setScaleLabel(scale)
    }
    
    @IBAction func occlusionSwitchValueDidChange(_ sender: UISwitch) {
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            guard let configuration = sceneView.session.configuration else { return }

            if sender.isOn {
                configuration.frameSemantics.insert(.personSegmentationWithDepth)
            } else {
                configuration.frameSemantics.remove(.personSegmentationWithDepth)
            }
            sceneView.session.run(configuration)
        }
    }
}
