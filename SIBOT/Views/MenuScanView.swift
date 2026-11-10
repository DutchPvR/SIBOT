import SwiftData
import SwiftUI

/// A photo to scan, wrapped so it can drive a sheet.
struct ScanImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Shows the safest dishes from a menu photo.
struct MenuScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let image: UIImage

    @State private var picks: [MenuPick] = []
    @State private var error: String?
    @State private var logged: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                if let error {
                    Text(error).foregroundStyle(.secondary)
                } else if picks.isEmpty {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Reading the menu…").foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(picks) { pick in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(pick.dish).font(.headline)
                                    Spacer()
                                    StatusBadge(status: pick.status)
                                }
                                Text(pick.reason)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button(logged.contains(pick.id) ? "Logged" : "Log it") {
                                    modelContext.insert(MealEntry(text: pick.dish, status: pick.status))
                                    logged.insert(pick.id)
                                }
                                .font(.subheadline.weight(.semibold))
                                .buttonStyle(.borderless)
                                .tint(Theme.purple)
                                .disabled(logged.contains(pick.id))
                            }
                            .padding(.vertical, 4)
                        }
                    } footer: {
                        Text("AI suggestions. Ask about garlic, onion and sauces when you order.")
                    }
                }
            }
            .navigationTitle("Menu picks")
            .navigationBarTitleDisplayMode(.inline)
            .groupedPage()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                do {
                    picks = try await MenuScanner.picks(for: image)
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

/// The system camera, for taking a photo of a menu.
struct CameraPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onPick(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
