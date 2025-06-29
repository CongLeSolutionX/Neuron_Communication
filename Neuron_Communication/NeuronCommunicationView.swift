//
//MIT License
//
//Copyright © 2025 Cong Le
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.
//
//
//  NeuronCommunicationView.swift
//  Neuron_Communication
//
//  Created by Cong Le on 6/29/25.
//
//

import SwiftUI

// MARK: - Model Layer
// These structs and enums define the data structures for our simulation.

/// Represents the current phase of the neuron's action potential.
enum ActionPotentialPhase: String, CaseIterable, Identifiable {
    case resting = "Resting"
    case depolarizing = "Depolarizing"
    case repolarizing = "Repolarizing"
    case hyperpolarizing = "Hyperpolarizing"
    case firing = "Firing" // A meta-state for UI purposes

    var id: String { self.rawValue }

    /// Provides a color representation for each phase, useful for UI feedback.
    var color: Color {
        switch self {
        case .resting: return .blue
        case .depolarizing: return .orange
        case .repolarizing: return .purple
        case .hyperpolarizing: return .cyan
        case .firing: return .red
        }
    }
}

/// Represents the effect a neurotransmitter has on the postsynaptic neuron.
enum PostsynapticEffect {
    case none
    case epsp // Excitatory Postsynaptic Potential
    case ipsp // Inhibitory Postsynaptic Potential
}

/// A simple structure to represent a neurotransmitter particle for animation.
struct NeurotransmitterParticle: Identifiable {
    let id = UUID()
}

// MARK: - ViewModel Layer
// This class holds the state and business logic for the simulation.
// It is the "brain" of our view, orchestrating the electrochemical events.

@MainActor
final class NeuronCommunicationViewModel: ObservableObject {
    // MARK: - Published Properties
    // These properties will automatically trigger UI updates when their values change.
    
    @Published var actionPotentialPhase: ActionPotentialPhase = .resting
    @Published var membraneVoltage: Double = -70.0
    @Published var voltageHistory: [Double] = Array(repeating: -70.0, count: 200)
    @Published var isFiring: Bool = false
    @Published var actionPotentialProgress: CGFloat = 0.0
    @Published var neurotransmitters: [NeurotransmitterParticle] = []
    @Published var postsynapticEffect: PostsynapticEffect = .none
    
    // MARK: - Simulation Constants
    // These constants define the biophysical parameters of our model neuron.
    
    let restingPotential: Double = -70.0
    let thresholdPotential: Double = -55.0
    let peakPotential: Double = 40.0
    
    // MARK: - Public Methods
    
    /// Entry point for stimulating the neuron.
    /// This function simulates the "all-or-none" principle.
    /// - Parameter stimulusStrength: The strength of the incoming signal.
    func applyStimulus(stimulusStrength: Double) {
        // Prevent re-firing while an action potential is already in progress.
        guard !isFiring else { return }
        
        // Convert slider value (0-100) to a voltage change.
        let potentialChange = restingPotential + stimulusStrength
        
        // ALL-OR-NONE PRINCIPLE: Check if the stimulus reaches the threshold.
        if potentialChange >= thresholdPotential {
            // Strong enough stimulus: trigger a full action potential.
            isFiring = true
            Task {
                await triggerActionPotential()
            }
        } else {
            // Weak stimulus: simulate a small, sub-threshold depolarization that fails to fire.
            Task {
                await showFailedStimulus(finalPotential: potentialChange)
            }
        }
    }

    /// Resets the simulation to its initial state.
    func reset() {
        actionPotentialPhase = .resting
        membraneVoltage = restingPotential
        voltageHistory = Array(repeating: restingPotential, count: 200)
        actionPotentialProgress = 0.0
        neurotransmitters.removeAll()
        postsynapticEffect = .none
        isFiring = false
    }
    
    // MARK: - Private Simulation Logic
    
    /// Simulates a sub-threshold potential that doesn't result in an action potential.
    private func showFailedStimulus(finalPotential: Double) async {
        let originalVoltage = self.membraneVoltage
        
        // Animate a brief rise in voltage
        await animateVoltageChange(to: finalPotential, duration: 0.1)
        self.actionPotentialPhase = .depolarizing
        
        try? await Task.sleep(for: .milliseconds(200))
        
        // Animate the voltage returning to the resting state
        await animateVoltageChange(to: originalVoltage, duration: 0.2)
        self.actionPotentialPhase = .resting
    }

    /// Orchestrates the full sequence of an action potential and synaptic transmission.
    /// Uses `async/await` to model the passage of time elegantly.
    private func triggerActionPotential() async {
        // --- 1. Depolarization ---
        actionPotentialPhase = .depolarizing
        await animateVoltageChange(to: peakPotential, duration: 0.2)

        // --- 2. Action Potential Propagation ---
        await animateActionPotentialPropagation()
        
        // --- 3. Repolarization ---
        actionPotentialPhase = .repolarizing
        await animateVoltageChange(to: restingPotential - 10.0, duration: 0.3)
        
        // --- 4. Hyperpolarization (Refractory Period) ---
        actionPotentialPhase = .hyperpolarizing
        
        // --- 5. Return to Rest ---
        await animateVoltageChange(to: restingPotential, duration: 0.4)
        actionPotentialPhase = .resting
        
        // --- 6. Reset Simulation State ---
        isFiring = false
    }
    
    /// Animates the voltage change over time and updates the history for the graph.
    private func animateVoltageChange(to targetVoltage: Double, duration: TimeInterval) async {
        // CORRECTED: Use .easeInOut(duration:) directly in withAnimation.
        withAnimation(.easeInOut(duration: duration)) {
            self.membraneVoltage = targetVoltage
        }
        
        // CORRECTED: To properly wait for an animation to finish visually,
        // we sleep for its duration. `withAnimation` itself is not `async`.
        try? await Task.sleep(for: .seconds(duration))
        
        voltageHistory.removeFirst()
        voltageHistory.append(targetVoltage)
    }
    
    /// Animates the visual pulse down the axon and triggers synaptic transmission at the end.
    private func animateActionPotentialPropagation() async {
        actionPotentialProgress = 0.0
        
        // CORRECTED: Use modern animation syntax and handle async timing correctly.
        withAnimation(.linear(duration: 0.5)) {
            self.actionPotentialProgress = 1.0
        }
        try? await Task.sleep(for: .seconds(0.5))
        
        await triggerSynapticTransmission()
        
        self.actionPotentialProgress = 0.0
    }
    
    /// Simulates the chemical communication at the synapse.
    private func triggerSynapticTransmission() async {
        neurotransmitters = (0..<10).map { _ in NeurotransmitterParticle() }
        
        try? await Task.sleep(for: .milliseconds(50))
        
        // CORRECTED: Use modern animation syntax and handle async timing correctly.
        withAnimation(.easeInOut(duration: 0.6)) {
            postsynapticEffect = .epsp // Simulate an excitatory effect
        }
        try? await Task.sleep(for: .seconds(0.6))

        try? await Task.sleep(for: .milliseconds(800))
        
        // CORRECTED: Use modern animation syntax and handle async timing correctly.
        withAnimation(.easeInOut(duration: 0.5)) {
            self.postsynapticEffect = .none
            self.neurotransmitters.removeAll()
        }
        try? await Task.sleep(for: .seconds(0.5))
    }
}


// MARK: - View Layer
// These views are responsible for rendering the UI based on the ViewModel's state.

struct NeuronCommunicationView: View {
    
    /// The single source of truth for the view's state and logic.
    @StateObject private var viewModel = NeuronCommunicationViewModel()

    /// Local state for the stimulus slider.
    @State private var stimulusStrength: Double = 20.0
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(phase: viewModel.actionPotentialPhase)
            
            // Simulation Canvas
            ZStack {
                Color.black.ignoresSafeArea()
                
                SynapseView(viewModel: viewModel)
            }
            .frame(height: 200)
            
            // Graph Display
            ActionPotentialGraph(voltageHistory: viewModel.voltageHistory)
                .frame(height: 150)
                .background(Color(.systemGray6))
                .overlay(GraphOverlay(voltage: viewModel.membraneVoltage, phase: viewModel.actionPotentialPhase))
            
            // Controls
            ControlsView(
                stimulusStrength: $stimulusStrength,
                threshold: viewModel.thresholdPotential,
                isFiring: viewModel.isFiring,
                fireAction: {
                    viewModel.applyStimulus(stimulusStrength: stimulusStrength)
                },
                resetAction: {
                    viewModel.reset()
                }
            )
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Neuron Communication")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subviews

/// Displays the current phase and a title.
private struct HeaderView: View {
    let phase: ActionPotentialPhase
    
    var body: some View {
        VStack {
            Text("Electrochemical Symphony")
                .font(.title2).bold()
                .foregroundStyle(.primary)
            
            HStack {
                Text("Current Phase:")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text(phase.rawValue)
                    .font(.headline.bold())
                    .foregroundStyle(phase.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(phase.color.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

/// Renders the two neurons and the animated synapse.
private struct SynapseView: View {
    @ObservedObject var viewModel: NeuronCommunicationViewModel
    
    var body: some View {
        GeometryReader { geo in
            let presynapticEnd = CGPoint(x: geo.size.width * 0.45, y: geo.size.height / 2)
            let postsynapticStart = CGPoint(x: geo.size.width * 0.55, y: geo.size.height / 2)
            
            // Postsynaptic Neuron (receives the signal)
            NeuronShape(startPoint: postsynapticStart, isPresynaptic: false)
                .fill(viewModel.postsynapticEffect == .epsp ? Color.green.opacity(0.8) : Color.gray.opacity(0.5))
                .animation(.easeInOut, value: viewModel.postsynapticEffect)
            
            // Neurotransmitter particles animation
            ForEach(viewModel.neurotransmitters) { _ in
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 8, height: 8)
                    .modifier(SynapseParticleEffect(
                        start: presynapticEnd,
                        end: postsynapticStart,
                        isComplete: viewModel.postsynapticEffect != .none
                    ))
            }
           
            // Presynaptic Neuron (sends the signal)
            ZStack {
                NeuronShape(startPoint: presynapticEnd, isPresynaptic: true)
                    .fill(Color.gray.opacity(0.5))
                
                // Action Potential Pulse Animation
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 20, height: 20)
                    .blur(radius: 5)
                     // CORRECTED: Swapped argument order to match the struct's memberwise initializer.
                    .modifier(ActionPotentialPulseEffect(
                        progress: viewModel.actionPotentialProgress,
                        pathStart: CGPoint(x: 0, y: geo.size.height / 2),
                        pathEnd: presynapticEnd
                    ))
                    .opacity(viewModel.isFiring ? 1 : 0)
            }
        }
    }
}

/// Renders the line graph of voltage over time.
private struct ActionPotentialGraph: View {
    let voltageHistory: [Double]
    
    var body: some View {
        Canvas { context, size in
            guard voltageHistory.count > 1 else { return }
            
            var path = Path()
            let step = size.width / Double(voltageHistory.count - 1)
            
            // Map voltage (-80 to 40) to view coordinates (size.height to 0)
            func y(for voltage: Double) -> Double {
                let range = 40.0 - (-80.0) // 120
                let normalized = (voltage - (-80.0)) / range
                return size.height * (1.0 - normalized)
            }
            
            path.move(to: CGPoint(x: 0, y: y(for: voltageHistory[0])))
            
            for i in 1..<voltageHistory.count {
                let point = CGPoint(x: Double(i) * step, y: y(for: voltageHistory[i]))
                path.addLine(to: point)
            }
            
            context.stroke(path, with: .color(.cyan), lineWidth: 2)
        }
    }
}

/// An overlay for the graph showing key voltage lines and current values.
private struct GraphOverlay: View {
    let voltage: Double
    let phase: ActionPotentialPhase
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Threshold line
                Path { path in
                    let y = geo.size.height * (1.0 - ((-55.0 - (-80.0)) / 120.0))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
                .stroke(Color.red.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5]))

                Text("Threshold (-55 mV)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .offset(y: geo.size.height * (1.0 - ((-55.0 - (-80.0)) / 120.0)) - 20)
                
                // Current Voltage Readout
                Text("\(Int(voltage)) mV")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(phase.color)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(5)
            }
        }
    }
}

/// Contains the user interaction controls.
private struct ControlsView: View {
    @Binding var stimulusStrength: Double
    let threshold: Double
    let isFiring: Bool
    let fireAction: () -> Void
    let resetAction: () -> Void
    
    // Calculates color based on whether the stimulus is sub- or super-threshold.
    private var stimulusColor: Color {
        (-70.0 + stimulusStrength) >= threshold ? .green : .orange
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // Stimulus Slider
            VStack {
                Text("Stimulus Strength: \(Int(stimulusStrength))")
                    .font(.headline)
                Slider(value: $stimulusStrength, in: 0...100, step: 1)
                    .accentColor(stimulusColor)
                Text("Simulates the combined strength of incoming signals.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Action Buttons
            HStack(spacing: 20) {
                Button(action: fireAction) {
                    Label("Fire Neuron", systemImage: "bolt.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(stimulusColor)
                .disabled(isFiring)
                
                Button(action: resetAction) {
                    Label("Reset", systemImage: "arrow.clockwise")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.bar)
    }
}


// MARK: - Custom Animation Modifiers

/// An animatable modifier to move a view along a path.
struct ActionPotentialPulseEffect: GeometryEffect {
    var progress: CGFloat = 0
    let pathStart: CGPoint
    let pathEnd: CGPoint

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = pathStart.x + (pathEnd.x - pathStart.x) * progress
        let y = pathStart.y + (pathEnd.y - pathStart.y) * progress
        let offset = CGAffineTransform(translationX: x - size.width / 2, y: y - size.height / 2)
        return ProjectionTransform(offset)
    }
}

/// An animatable modifier for the neurotransmitter particles.
struct SynapseParticleEffect: GeometryEffect {
    let start: CGPoint
    let end: CGPoint
    var isComplete: Bool

    var animatableData: CGFloat {
        get { isComplete ? 1 : 0 }
        set { isComplete = newValue > 0.5 }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let progress = isComplete ? 1.0 : 0.0
        // CORRECTED: Changed Int literals to Double to avoid type mismatch errors.
        let onCurve = CGPoint(x: start.x + (end.x - start.x) / 2.0, y: start.y - 40.0)
        
        // Quadratic Bézier curve calculation
        let q0 = start
        let q1 = q0.lerp(to: onCurve, t: progress)
        let q2 = onCurve.lerp(to: end, t: progress)
        let finalPos = q1.lerp(to: q2, t: progress)

        let offset = CGAffineTransform(translationX: finalPos.x - size.width/2 + .random(in: -20...20), y: finalPos.y - size.height/2 + .random(in: -10...10))
        let scale = 1.0 - progress
        let scaleTransform = ProjectionTransform(CGAffineTransform(scaleX: scale, y: scale))
        
        return ProjectionTransform(offset).concatenating(scaleTransform)
    }
}

// MARK: - Helper Extensions & Shapes

/// A custom `Shape` to draw a stylized neuron.
struct NeuronShape: Shape {
    let startPoint: CGPoint
    let isPresynaptic: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // CORRECTED: Changed Int literals to floating point to match Core Graphics APIs.
        if isPresynaptic {
            // Presynaptic: Axon -> Terminal
            let axonStart = CGPoint(x: 0.0, y: rect.midY)
            let terminalEnd = CGPoint(x: startPoint.x - 20.0, y: startPoint.y)
            path.move(to: axonStart)
            path.addLine(to: terminalEnd)
            path.addEllipse(in: CGRect(center: startPoint, radius: 20.0))
        } else {
            // Postsynaptic: Dendrite/Soma
            let dendriteStart = CGPoint(x: startPoint.x + 20.0, y: startPoint.y)
            let somaEnd = CGPoint(x: rect.maxX, y: rect.midY)
            path.addEllipse(in: CGRect(center: startPoint, radius: 20.0))
            path.move(to: dendriteStart)
            path.addLine(to: somaEnd)
        }
        
        return path
    }
}

extension CGPoint {
    /// Linear interpolation between two points.
    func lerp(to other: CGPoint, t: CGFloat) -> CGPoint {
        return CGPoint(
            x: self.x + (other.x - self.x) * t,
            y: self.y + (other.y - self.y) * t
        )
    }
}

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    init(center: CGPoint, radius: CGFloat) {
        self.init(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}

// MARK: - Preview
struct NeuronCommunicationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NeuronCommunicationView()
        }
    }
}
