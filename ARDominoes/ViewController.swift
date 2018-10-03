//
//  ViewController.swift
//  ARDominoes
//
//  Created by Koushan Korouei on 03/10/2018.
//  Copyright © 2018 Koushan Korouei. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var detectedPlanes: [String : SCNNode] = [:]
    var dominoes: [SCNNode] = []
    var previousDominoPosition: SCNVector3?
    let dominoColors: [UIColor] = [.red, .blue, .green, .yellow, .orange, .cyan, .magenta, .purple]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a new scene
        let scene = SCNScene()
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.scene = scene
        sceneView.scene.physicsWorld.timeStep = 1/200
        // Gesture
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(screenPanned))
        sceneView.addGestureRecognizer(panGesture)
        // Lights
        addLights()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        // Add horizontal plane detection
        configuration.planeDetection = .horizontal

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @objc func screenPanned(gesture: UIPanGestureRecognizer) {
        // Stop plane detection
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
        // Get the hit-test result
        let location = gesture.location(in: sceneView)
        guard let hitTestResult = sceneView.hitTest(location, types: .existingPlane).first else { return }
        guard let previousPosition = previousDominoPosition else {
            self.previousDominoPosition = SCNVector3Make(hitTestResult.worldTransform.columns.3.x,
                                                         hitTestResult.worldTransform.columns.3.y,
                                                         hitTestResult.worldTransform.columns.3.z)
            return
        }
        // Get the distance
        let currentPosition = SCNVector3Make(hitTestResult.worldTransform.columns.3.x,
                                             hitTestResult.worldTransform.columns.3.y,
                                             hitTestResult.worldTransform.columns.3.z)
        let minimumDistanceBetweenDominoes: Float = 0.03
        let distance = distanceBetween(point1: previousPosition, andPoint2: currentPosition)
        if distance >= minimumDistanceBetweenDominoes {
            // Create domino and add random color
            let dominoGeometry = SCNBox(width: 0.007, height: 0.06, length: 0.03, chamferRadius: 0.0)
            dominoGeometry.firstMaterial?.diffuse.contents = dominoColors.randomElement()
            let dominoNode = SCNNode(geometry: dominoGeometry)
            dominoNode.position = SCNVector3Make(currentPosition.x,
                                                 currentPosition.y + 0.03,
                                                 currentPosition.z)
            // Rotate domino
            var currentAngle: Float = pointPairToBearingDegrees(startingPoint: CGPoint(x: CGFloat(currentPosition.x), y: CGFloat(currentPosition.z)), secondPoint: CGPoint(x: CGFloat(previousPosition.x), y: CGFloat(previousPosition.z)))
            currentAngle *= .pi / 180
            dominoNode.rotation = SCNVector4Make(0, 1, 0, -currentAngle)
            // Physics
            dominoNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
            dominoNode.physicsBody?.mass = 2.0
            dominoNode.physicsBody?.friction = 0.8
            
            sceneView.scene.rootNode.addChildNode(dominoNode)
            dominoes.append(dominoNode)
            self.previousDominoPosition = currentPosition
        }
    }
    
    func addLights() {
        
        // Directional Light
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 500
        directionalLight.castsShadow = true
        directionalLight.shadowMode = .deferred
        directionalLight.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        let directionalLightNode = SCNNode()
        directionalLightNode.light = directionalLight
        // Rotate light downwards
        directionalLightNode.rotation = SCNVector4Make(1, 0, 0, -Float.pi / 3)
        sceneView.scene.rootNode.addChildNode(directionalLightNode)
        // Ambient Light
        let ambientLight = SCNLight()
        ambientLight.intensity = 50
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        sceneView.scene.rootNode.addChildNode(ambientLightNode)
    }
    
    // MARK:- IBAction
    @IBAction func removeAllDominoesButtonPressed(_ sender: Any) {
        // Remove all the dominoes from the scene to start fresh
        for domino in dominoes {
            domino.removeFromParentNode()
            self.previousDominoPosition = nil
        }
        dominoes = []
    }
    
    @IBAction func startButtonPressed(_ sender: Any) {
        // Apply force as impulse to the first domino
        guard let firstDomino = dominoes.first else { return }
        let power: Float = 0.7
        firstDomino.physicsBody?.applyForce(SCNVector3Make(firstDomino.worldRight.x * power,
                                                           firstDomino.worldRight.y * power,
                                                           firstDomino.worldRight.z * power),
                                            asImpulse: true)
    }

    // MARK:- ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Create planes to represent the floor
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        plane.firstMaterial?.colorBufferWriteMask = .init(rawValue: 0)
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3Make(planeAnchor.center.x,
                                            planeAnchor.center.y,
                                            planeAnchor.center.z)
        planeNode.rotation = SCNVector4Make(1, 0, 0, -Float.pi / 2.0)
        // Physics
        let box = SCNBox(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z), length: 0.001, chamferRadius: 0)
        planeNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))

        node.addChildNode(planeNode)
        detectedPlanes[planeAnchor.identifier.uuidString] = planeNode
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Update the planes size and position
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        guard let planeNode = detectedPlanes[planeAnchor.identifier.uuidString] else { return }
        let planeGeometry = planeNode.geometry as! SCNPlane
        planeGeometry.width = CGFloat(planeAnchor.extent.x)
        planeGeometry.height = CGFloat(planeAnchor.extent.z)
        planeNode.position = SCNVector3Make(planeAnchor.center.x,
                                            planeAnchor.center.y,
                                            planeAnchor.center.z)
        // Update the physics shape
        let box = SCNBox(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z), length: 0.001, chamferRadius: 0)
        planeNode.physicsBody?.physicsShape = SCNPhysicsShape(geometry: box, options: nil)
    }
    
    // MARK: - Helper Methods
    func distanceBetween(point1: SCNVector3, andPoint2 point2: SCNVector3) -> Float {
        
        return hypotf(Float(point1.x - point2.x), Float(point1.z - point2.z))
    }
    
    func pointPairToBearingDegrees(startingPoint: CGPoint, secondPoint endingPoint: CGPoint) -> Float{
        
        let originPoint: CGPoint = CGPoint(x: startingPoint.x - endingPoint.x, y: startingPoint.y - endingPoint.y)
        let bearingRadians = atan2f(Float(originPoint.y), Float(originPoint.x))
        let bearingDegrees = bearingRadians * (180.0 / Float.pi)
        return bearingDegrees
    }
}
