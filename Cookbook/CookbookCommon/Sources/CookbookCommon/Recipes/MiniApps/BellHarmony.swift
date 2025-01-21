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
    
    @Published var useTubularBells: Bool = true {
        didSet {
            // Stop all currently playing notes when switching instruments
            for i in 0..<notes.count {
                if notes[i] != 0 {
                    if useTubularBells {
                        env2[i].closeGate() // Close previous instrument's gates
                    } else {
                        env[i].closeGate()
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
    
    var numPlaying = 0
    func noteOn(pitch: Pitch, velocity: Int = 127) {
        numPlaying += 1
        if numPlaying > 10 {
            numPlaying = 0
        }
        if useTubularBells {
            osc[numPlaying].trigger(note: MIDINoteNumber(pitch.intValue), velocity: MIDIVelocity(velocity))
            env[numPlaying].openGate()
        } else {
            osc2[numPlaying].trigger(note: MIDINoteNumber(pitch.intValue), velocity: MIDIVelocity(velocity))
            env2[numPlaying].openGate()
        }
        notes[numPlaying] = pitch.intValue
    }
    
    func noteOn(pitch: Pitch, point _: CGPoint) {
        noteOn(pitch: pitch, velocity: 120)
        
    }
    
    func noteOff(pitch: Pitch) {
        for num in 0 ... 10 {
            if notes[num] == pitch.intValue {
                if useTubularBells {
                    env[num].closeGate()
                } else {
                    env2[num].closeGate()
                }
                notes[num] = 0
            }
        }
    }
    
    func playBellChord1() {
        // Clear any currently playing notes
        for i in 0..<notes.count {
            if notes[i] != 0 {
                if useTubularBells {
                    env[i].closeGate()
                } else {
                    env2[i].closeGate()
                }
                notes[i] = 0
            }
        }
        
        // Play the chord notes
        let chordNotes = [63, 72, 79, 85, 90, 95] // D#3, C4, G4, C#5, F#5, B5
        for (index, note) in chordNotes.enumerated() {
            if useTubularBells {
                osc[index].trigger(note: MIDINoteNumber(note), velocity: 100)
                env[index].openGate()
            } else {
                osc2[index].trigger(note: MIDINoteNumber(note), velocity: 100)
                env2[index].openGate()
            }
            notes[index] = note
        }
    }
    
    init() {
        env = [AmplitudeEnvelope(osc[0]),AmplitudeEnvelope(osc[1]),AmplitudeEnvelope(osc[2]),AmplitudeEnvelope(osc[3]),AmplitudeEnvelope(osc[4]),AmplitudeEnvelope(osc[5]),AmplitudeEnvelope(osc[6]),AmplitudeEnvelope(osc[7]),AmplitudeEnvelope(osc[8]),AmplitudeEnvelope(osc[9]),AmplitudeEnvelope(osc[10])]
        env2 = [AmplitudeEnvelope(osc2[0]),AmplitudeEnvelope(osc2[1]),AmplitudeEnvelope(osc2[2]),AmplitudeEnvelope(osc2[3]),AmplitudeEnvelope(osc2[4]),AmplitudeEnvelope(osc2[5]),AmplitudeEnvelope(osc2[6]),AmplitudeEnvelope(osc2[7]),AmplitudeEnvelope(osc2[8]),AmplitudeEnvelope(osc2[9]),AmplitudeEnvelope(osc2[10])]
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

        engine.output = mixer

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

    var body: some View {
        VStack {
            if conductor.engine.output != nil {
                NodeOutputView(conductor.engine.output!)
            }
            
            HStack {
                Button(action: {
                    conductor.useTubularBells = true
                }) {
                    Text("Tubular Bells")
                        .foregroundColor(conductor.useTubularBells ? .green : .blue)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8)
                            .stroke(conductor.useTubularBells ? Color.green : Color.blue))
                }
                
                Button(action: {
                    conductor.useTubularBells = false
                }) {
                    Text("Rhodes Piano")
                        .foregroundColor(!conductor.useTubularBells ? .green : .blue)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8)
                            .stroke(!conductor.useTubularBells ? Color.green : Color.blue))
                }
            }
            .padding()
            
            Button(action: {
                conductor.playBellChord1()
            }) {
                Text("Bell Chord 1")
                    .foregroundColor(.blue)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.blue))
            }
            .padding()
            
            MIDIKitKeyboard(noteOn: conductor.noteOn,
                           noteOff: conductor.noteOff)
        }
        .cookbookNavBarTitle("Bell Harmony")
        .onAppear {
            conductor.start()
        }
        .onDisappear {
            conductor.stop()
        }
        .background(colorScheme == .dark ?
                   Color.clear : Color(red: 0.9, green: 0.9, blue: 0.9))
    }
}
