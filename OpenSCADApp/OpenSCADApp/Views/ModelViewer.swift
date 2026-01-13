import SwiftUI
import SceneKit

struct ModelViewer: NSViewRepresentable {
    let modelData: Data?
    let isLoading: Bool

    func makeNSView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = SCNScene()
        sceneView.backgroundColor = NSColor.windowBackgroundColor
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.showsStatistics = false

        setupDefaultCamera(in: sceneView.scene!)
        setupLighting(in: sceneView.scene!)

        if modelData == nil {
            addPlaceholder(to: sceneView.scene!)
        }

        return sceneView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        guard let scene = nsView.scene else { return }

        scene.rootNode.childNodes.filter { $0.name == "model" || $0.name == "placeholder" }
            .forEach { $0.removeFromParentNode() }

        if let data = modelData {
            loadModel(from: data, into: scene)
        } else if !isLoading {
            addPlaceholder(to: scene)
        }
    }

    private func setupDefaultCamera(in scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 30, y: 30, z: 30)
        cameraNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(cameraNode)
    }

    private func setupLighting(in scene: SCNScene) {
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 500
        ambientLight.light?.color = NSColor.white
        scene.rootNode.addChildNode(ambientLight)

        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 1000
        directionalLight.position = SCNVector3(x: 50, y: 50, z: 50)
        directionalLight.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(directionalLight)
    }

    private func addPlaceholder(to scene: SCNScene) {
        let gridNode = createGrid()
        gridNode.name = "placeholder"
        scene.rootNode.addChildNode(gridNode)

        let textNode = createWelcomeText()
        textNode.name = "placeholder"
        scene.rootNode.addChildNode(textNode)
    }

    private func createGrid() -> SCNNode {
        let gridNode = SCNNode()

        for i in -5...5 {
            let lineX = SCNBox(width: 100, height: 0.1, length: 0.1, chamferRadius: 0)
            lineX.firstMaterial?.diffuse.contents = NSColor.gray.withAlphaComponent(0.3)
            let lineNodeX = SCNNode(geometry: lineX)
            lineNodeX.position = SCNVector3(x: 0, y: 0, z: CGFloat(i) * 10)
            gridNode.addChildNode(lineNodeX)

            let lineZ = SCNBox(width: 0.1, height: 0.1, length: 100, chamferRadius: 0)
            lineZ.firstMaterial?.diffuse.contents = NSColor.gray.withAlphaComponent(0.3)
            let lineNodeZ = SCNNode(geometry: lineZ)
            lineNodeZ.position = SCNVector3(x: CGFloat(i) * 10, y: 0, z: 0)
            gridNode.addChildNode(lineNodeZ)
        }

        return gridNode
    }

    private func createWelcomeText() -> SCNNode {
        let text = SCNText(string: "Run script to preview", extrusionDepth: 1)
        text.font = NSFont.systemFont(ofSize: 3)
        text.firstMaterial?.diffuse.contents = NSColor.secondaryLabelColor

        let textNode = SCNNode(geometry: text)
        let (min, max) = textNode.boundingBox
        let width = max.x - min.x
        textNode.position = SCNVector3(x: -width / 2, y: 10, z: 0)

        return textNode
    }

    private func loadModel(from data: Data, into scene: SCNScene) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("preview.stl")

        do {
            try data.write(to: tempURL)

            if let loadedScene = try? SCNScene(url: tempURL, options: [
                .createNormalsIfAbsent: true,
                .convertToYUp: true
            ]) {
                for child in loadedScene.rootNode.childNodes {
                    let modelNode = child.clone()
                    modelNode.name = "model"

                    let material = SCNMaterial()
                    material.diffuse.contents = NSColor.systemBlue
                    material.specular.contents = NSColor.white
                    material.shininess = 0.5
                    modelNode.geometry?.materials = [material]

                    scene.rootNode.addChildNode(modelNode)
                }
            }

            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            print("Failed to load model: \(error)")
        }
    }
}

struct ModelViewerOverlay: View {
    let isLoading: Bool

    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.3)
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Rendering...")
                        .foregroundColor(.white)
                        .padding(.top)
                }
            }
        }
    }
}

#Preview {
    ModelViewer(modelData: nil, isLoading: false)
        .frame(width: 400, height: 400)
}
