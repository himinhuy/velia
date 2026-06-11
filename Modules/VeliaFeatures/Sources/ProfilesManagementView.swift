import SwiftUI
import VeliaDesignSystem

/// Manage local profiles: add, rename, set/clear PIN, delete, and switch (lock back to the gate).
struct ProfilesManagementView: View {
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss) private var dismiss

    @State private var renaming: ProfileInfo?
    @State private var renameText = ""
    @State private var settingPINFor: ProfileInfo?
    @State private var addingName: String?

    var body: some View {
        List {
            Section {
                ForEach(profiles.profiles) { info in
                    HStack {
                        Image(systemName: "person.crop.circle.fill").foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profiles.displayName(info))
                            if info.hasPIN {
                                Label(L2("Có mã PIN", "PIN set"), systemImage: "lock.fill")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if info.id == profiles.activeID {
                            Text(L2("Đang dùng", "Active")).font(.caption).foregroundStyle(Theme.accent)
                        }
                    }
                    .swipeActions {
                        if profiles.profiles.count > 1 {
                            Button(role: .destructive) { profiles.deleteProfile(info.id) } label: {
                                Label(L2("Xóa", "Delete"), systemImage: "trash")
                            }
                        }
                        Button { renaming = info; renameText = info.name } label: {
                            Label(L2("Đổi tên", "Rename"), systemImage: "pencil")
                        }.tint(.gray)
                    }
                    .contextMenu {
                        Button { renaming = info; renameText = info.name } label: {
                            Label(L2("Đổi tên", "Rename"), systemImage: "pencil")
                        }
                        if info.hasPIN {
                            Button { profiles.setPIN(nil, for: info.id) } label: {
                                Label(L2("Xóa mã PIN", "Remove PIN"), systemImage: "lock.open")
                            }
                            Button { settingPINFor = info } label: {
                                Label(L2("Đổi mã PIN", "Change PIN"), systemImage: "lock.rotation")
                            }
                        } else {
                            Button { settingPINFor = info } label: {
                                Label(L2("Đặt mã PIN", "Set PIN"), systemImage: "lock")
                            }
                        }
                    }
                }
            } footer: {
                Text(L2("Mỗi hồ sơ có dữ liệu mã hóa riêng trên máy này. Vuốt để đổi tên hoặc xóa; nhấn giữ để đặt mã PIN.",
                        "Each profile has its own encrypted data on this device. Swipe to rename or delete; long-press to set a PIN."))
            }

            Section {
                Button { addingName = "" } label: {
                    Label(L2("Thêm hồ sơ", "Add profile"), systemImage: "plus")
                }
                Button { profiles.lockToGate() } label: {
                    Label(L2("Đổi hồ sơ / khóa", "Switch profile / lock"), systemImage: "arrow.left.arrow.right")
                }
            }
        }
        .navigationTitle(L2("Hồ sơ người dùng", "Profiles"))
        // Rename
        .alert(L2("Đổi tên hồ sơ", "Rename profile"), isPresented: Binding(
            get: { renaming != nil }, set: { if !$0 { renaming = nil } }
        )) {
            TextField(L2("Tên", "Name"), text: $renameText)
            Button(L2("Lưu", "Save")) { if let r = renaming { profiles.rename(r.id, to: renameText) }; renaming = nil }
            Button(L2("Hủy", "Cancel"), role: .cancel) { renaming = nil }
        }
        // Add
        .alert(L2("Thêm hồ sơ", "Add profile"), isPresented: Binding(
            get: { addingName != nil }, set: { if !$0 { addingName = nil } }
        )) {
            TextField(L2("Tên", "Name"), text: Binding(get: { addingName ?? "" }, set: { addingName = $0 }))
            Button(L2("Tạo", "Create")) {
                profiles.createProfile(name: addingName ?? "", pin: nil); addingName = nil
            }
            Button(L2("Hủy", "Cancel"), role: .cancel) { addingName = nil }
        }
        // Set / change PIN
        .sheet(item: $settingPINFor) { info in
            PINEntryView(
                title: L2("Đặt mã PIN", "Set PIN"),
                subtitle: L2("4–6 chữ số cho \(profiles.displayName(info))", "4–6 digits for \(profiles.displayName(info))"),
                onSubmit: { pin in profiles.setPIN(pin, for: info.id); settingPINFor = nil; return true },
                onCancel: { settingPINFor = nil }
            )
        }
    }
}
