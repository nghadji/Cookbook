import AudioKit
import AudioKitEX
import AudioKitUI
import AudioToolbox
import Keyboard
import SoundpipeAudioKit
import STKAudioKit
import SwiftUI
import Tonic
import MIDIKit
import DunneAudioKit

class BellHarmonyConductor: ObservableObject, HasAudioEngine {
    let engine = AudioEngine()
    let mixer = Mixer()
    var notes = Array(repeating: 0, count: 11)
    var osc2 = [RhodesPianoKey(), RhodesPianoKey(), RhodesPianoKey(), RhodesPianoKey(), RhodesPianoKey(),
               RhodesPianoKey(), RhodesPianoKey(), RhodesPianoKey(), RhodesPianoKey(), RhodesPianoKey(), RhodesPianoKey()]
    var osc = [TubularBells(), TubularBells(), TubularBells(), TubularBells(), TubularBells(),
                TubularBells(), TubularBells(), TubularBells(), TubularBells(), TubularBells(), TubularBells()]         
    var osc3 = [Clarinet(), Clarinet(), Clarinet(), Clarinet(), Clarinet(),
                Clarinet(), Clarinet(), Clarinet(), Clarinet(), Clarinet(), Clarinet()]   
    
    // Filter setup
    var filter: MoogLadder!
    
    @Published var cutoffFrequency: AUValue = 1_000 {
        didSet {
            filter.cutoffFrequency = cutoffFrequency
        }
    }
    
    @Published var resonance: AUValue = 0.3 {
        didSet {
            filter.resonance = resonance
        }
    }
    
    enum InstrumentType {
        case tubularBells
        case rhodesPiano
        case clarinet
    }
    
    @Published var currentInstrument: InstrumentType = .tubularBells {
        didSet {
            // Stop all currently playing notes when switching instruments
            for i in 0..<notes.count {
                if notes[i] != 0 {
                    switch oldValue {
                    case .tubularBells:
                        env[i].closeGate()
                    case .rhodesPiano:
                        env2[i].closeGate()
                    case .clarinet:
                        osc3[i].trigger(note: 0, velocity: 0)
                        env3[i].closeGate()
                    }
                    notes[i] = 0
                }
            }
        }
    }
    
    // MIDI Manager (MIDI methods are in SoundFont+MIDI)
    let midiManager = MIDIManager(
        clientName: "TestAppMIDIManager",
        model: "TestApp",
        manufacturer: "MyCompany"
    )
    
    var env: Array<AmplitudeEnvelope>
    var env2: Array<AmplitudeEnvelope>
    var env3: Array<AmplitudeEnvelope>
    
    var numPlaying = 0
    func noteOn(pitch: Pitch, velocity: Int = 127) {
        numPlaying += 1
        if numPlaying > 10 {
            numPlaying = 0
        }
        
        switch currentInstrument {
        case .tubularBells:
            osc[numPlaying].trigger(note: MIDINoteNumber(pitch.intValue), velocity: MIDIVelocity(velocity))
            env[numPlaying].openGate()
        case .rhodesPiano:
            osc2[numPlaying].trigger(note: MIDINoteNumber(pitch.intValue), velocity: MIDIVelocity(velocity))
            env2[numPlaying].openGate()
        case .clarinet:
            osc3[numPlaying].trigger(note: MIDINoteNumber(pitch.intValue), velocity: MIDIVelocity(velocity))
            env3[numPlaying].attackDuration = 0.02
            env3[numPlaying].releaseDuration = 0.1
            env3[numPlaying].openGate()
        }
        notes[numPlaying] = pitch.intValue
    }
    
    func noteOn(pitch: Pitch, point _: CGPoint) {
        noteOn(pitch: pitch, velocity: 120)
    }
    
    func noteOff(pitch: Pitch) {
        for num in 0 ... 10 {
            if notes[num] == pitch.intValue {
                switch currentInstrument {
                case .tubularBells:
                    env[num].closeGate()
                case .rhodesPiano:
                    env2[num].closeGate()
                case .clarinet:
                    osc3[num].trigger(note: 0, velocity: 0)
                    env3[num].closeGate()
                }
                notes[num] = 0
            }
        }
    }
    
    func playBellChord1() {
        // Clear any currently playing notes
        for i in 0..<notes.count {
            if notes[i] != 0 {
                switch currentInstrument {
                case .tubularBells:
                    env[i].closeGate()
                case .rhodesPiano:
                    env2[i].closeGate()
                case .clarinet:
                    osc3[i].trigger(note: 0, velocity: 0)
                    env3[i].closeGate()
                }
                notes[i] = 0
            }
        }
        
        // Play the chord notes
        let chordNotes = [63, 72, 79, 85, 90, 95] // D#3, C4, G4, C#5, F#5, B5
        for (index, note) in chordNotes.enumerated() {
            switch currentInstrument {
            case .tubularBells:
                osc[index].trigger(note: MIDINoteNumber(note), velocity: 100)
                env[index].openGate()
            case .rhodesPiano:
                osc2[index].trigger(note: MIDINoteNumber(note), velocity: 100)
                env2[index].openGate()
            case .clarinet:
                osc3[index].trigger(note: MIDINoteNumber(note), velocity: 100)
                env3[index].attackDuration = 0.02
                env3[index].releaseDuration = 0.1
                env3[index].openGate()
                
                // Schedule note off after a fixed duration for the chord
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.osc3[index].trigger(note: 0, velocity: 0)
                    self?.env3[index].closeGate()
                    self?.notes[index] = 0
                }
            }
            notes[index] = note
        }
    }
    
    init() {
        env = [AmplitudeEnvelope(osc[0]),AmplitudeEnvelope(osc[1]),AmplitudeEnvelope(osc[2]),AmplitudeEnvelope(osc[3]),AmplitudeEnvelope(osc[4]),AmplitudeEnvelope(osc[5]),AmplitudeEnvelope(osc[6]),AmplitudeEnvelope(osc[7]),AmplitudeEnvelope(osc[8]),AmplitudeEnvelope(osc[9]),AmplitudeEnvelope(osc[10])]
        env2 = [AmplitudeEnvelope(osc2[0]),AmplitudeEnvelope(osc2[1]),AmplitudeEnvelope(osc2[2]),AmplitudeEnvelope(osc2[3]),AmplitudeEnvelope(osc2[4]),AmplitudeEnvelope(osc2[5]),AmplitudeEnvelope(osc2[6]),AmplitudeEnvelope(osc2[7]),AmplitudeEnvelope(osc2[8]),AmplitudeEnvelope(osc2[9]),AmplitudeEnvelope(osc2[10])]
        env3 = [AmplitudeEnvelope(osc3[0]),AmplitudeEnvelope(osc3[1]),AmplitudeEnvelope(osc3[2]),AmplitudeEnvelope(osc3[3]),AmplitudeEnvelope(osc3[4]),AmplitudeEnvelope(osc3[5]),AmplitudeEnvelope(osc3[6]),AmplitudeEnvelope(osc3[7]),AmplitudeEnvelope(osc3[8]),AmplitudeEnvelope(osc3[9]),AmplitudeEnvelope(osc3[10])]

        // Configure envelopes for all instruments
        for envelope in env {
            envelope.attackDuration = 0
            envelope.releaseDuration = 0.2
            mixer.addInput(envelope)
        }
        
        for envelope in env2 {
            envelope.attackDuration = 0
            envelope.releaseDuration = 0.2
            mixer.addInput(envelope)
        }
        
        // Configure Clarinet envelopes with shorter attack/release times
        for envelope in env3 {
            envelope.attackDuration = 0.02  // Short attack for responsiveness
            envelope.releaseDuration = 0.1  // Quick release to avoid lingering
            mixer.addInput(envelope)
        }
        
        // Set up filter after mixer is configured
        filter = MoogLadder(mixer)
        filter.cutoffFrequency = cutoffFrequency
        filter.resonance = resonance
        
        engine.output = filter
        
        // Set up MIDI
        MIDIConnect()
    } 
    
    // Connect MIDI on init
    func MIDIConnect() {
        do {
            print("Starting MIDI services.")
            try midiManager.start()
        } catch {
            print("Error starting MIDI services:", error.localizedDescription)
        }

        do {
            try midiManager.addInputConnection(
                to: .allOutputs, // no need to specify if we're using .allOutputs
                tag: "Listener",
                filter: .owned(), // don't allow self-created virtual endpoints
                receiver: .events { [weak self] events, timeStamp, source in
                    // Note: this handler will be called on a background thread
                    // so call the next line on main if it may result in UI updates
                    DispatchQueue.main.async {
                        events.forEach { self?.received(midiEvent: $0) }
                    }
                }
            )
        } catch {
            print(
                "Error setting up managed MIDI all-listener connection:",
                error.localizedDescription
            )
        }
    }

    // MIDI Events
    private func received(midiEvent: MIDIKit.MIDIEvent) {
        switch midiEvent {
        case .noteOn(let payload):
            print("Note On:", payload.note, payload.velocity, payload.channel)
            noteOn(pitch: Pitch(Int8(payload.note.number.uInt8Value)),
                   velocity: Int(payload.velocity.midi1Value.uInt8Value))
            NotificationCenter.default.post(name: .MIDIKey, object: nil,
                                            userInfo: ["info": payload.note.number.uInt8Value, "bool": true])
        case .noteOff(let payload):
            print("Note Off:", payload.note, payload.velocity, payload.channel)
            noteOff(pitch: Pitch(Int8(payload.note.number.uInt8Value)))
            NotificationCenter.default.post(name: .MIDIKey, object: nil,
                                            userInfo: ["info": payload.note.number.uInt8Value, "bool": false])
        case .cc(let payload):
            print("CC:", payload.controller, payload.value, payload.channel)
        case .programChange(let payload):
            print("Program Change:", payload.program, payload.channel)
        default:
            break
        }
    }
}

extension NSNotification.Name {
    static let MIDIKey = Notification.Name("MIDIKey")
}

struct BellHarmonyView: View {
    @StateObject var conductor = BellHarmonyConductor()
    @Environment(\.colorScheme) var colorScheme
    @State private var showFFT = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Audio Visualization Section
                VStack(spacing: 12) {
                    Text("Audio Visualization")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if conductor.engine.output != nil {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.05))
                            
                            VStack(spacing: 8) {
                                if showFFT {
                                    FFTView(conductor.engine.output!)
                                        .frame(height: 120)
                                } else {
                                    NodeOutputView(conductor.engine.output!)
                                        .frame(height: 120)
                                }
                                
                                Button(action: { showFFT.toggle() }) {
                                    HStack {
                                        Image(systemName: showFFT ? "waveform" : "chart.bar")
                                        Text(showFFT ? "Show Waveform" : "Show Spectrum")
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        Capsule()
                                            .stroke(Color.blue, lineWidth: 1)
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
                .padding(.horizontal)
                
                // Instrument Selection
                VStack(spacing: 12) {
                    Text("Instrument")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach([
                            (title: "Tubular Bells", type: BellHarmonyConductor.InstrumentType.tubularBells),
                            (title: "Rhodes Piano", type: BellHarmonyConductor.InstrumentType.rhodesPiano),
                            (title: "Clarinet", type: BellHarmonyConductor.InstrumentType.clarinet)
                        ], id: \.title) { instrument in
                            Button(action: { conductor.currentInstrument = instrument.type }) {
                                VStack {
                                    Image(systemName: instrument.type == .tubularBells ? "bell" :
                                            instrument.type == .rhodesPiano ? "pianokeys" : "music.note")
                                        .font(.system(size: 24))
                                    Text(instrument.title)
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(conductor.currentInstrument == instrument.type ?
                                             Color.blue.opacity(0.1) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(conductor.currentInstrument == instrument.type ?
                                               Color.blue : Color.gray.opacity(0.3))
                                )
                                .foregroundColor(conductor.currentInstrument == instrument.type ?
                                               .blue : .primary)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Filter Controls
                VStack(spacing: 12) {
                    Text("Filter")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "waveform.path")
                                Text("Cutoff")
                                Spacer()
                                Text(String(format: "%.0f Hz", conductor.cutoffFrequency))
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            
                            Slider(value: $conductor.cutoffFrequency, in: 20...20_000) {
                                Text("Cutoff Frequency")
                            }
                            .accentColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "dial.high")
                                Text("Resonance")
                                Spacer()
                                Text(String(format: "%.2f", conductor.resonance))
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            
                            Slider(value: $conductor.resonance, in: 0...0.75) {
                                Text("Resonance")
                            }
                            .accentColor(.blue)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.05))
                    )
                }
                .padding(.horizontal)
                
                // Bell Chord Button
                Button(action: { conductor.playBellChord1() }) {
                    HStack {
                        Image(systemName: "music.note.list")
                        Text("Play Bell Chord")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
                }
                .padding(.vertical)
                
                // Keyboard
                VStack(spacing: 12) {
                    Text("Keyboard")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    MIDIKitKeyboard(noteOn: conductor.noteOn,
                                  noteOff: conductor.noteOff)
                        .frame(height: 120)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .cookbookNavBarTitle("Bell Harmony")
        .onAppear {
            conductor.start()
        }
        .onDisappear {
            conductor.stop()
        }
        .background(colorScheme == .dark ?
                   Color.black : Color(red: 0.97, green: 0.97, blue: 0.97))
    }
}