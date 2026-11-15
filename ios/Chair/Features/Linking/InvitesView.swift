//
//  InvitesView.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct InvitesView: View {
    let center: InviteCenter

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Group {
                    if center.invites.isEmpty {
                        Text("No invites right now")
                            .chairFont(.body)
                            .foregroundStyle(Color.chair.inkSecondary)
                    }
                    ForEach(center.invites) { invite in
                        row(invite)
                    }
                    if let error = center.errorMessage {
                        Text(error)
                            .chairFont(.callout)
                            .foregroundStyle(Color.chair.danger)
                    }
                }
                .listRowBackground(Color.chair.control)
            }
            .scrollContentBackground(.hidden)
            .background(Color.chair.surface)
            .tint(Color.chair.tint)
            .navigationTitle("Invites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: handleDone())
                }
            }
            .task(handleRefresh())
        }
    }

    private func row(_ invite: Invite) -> some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xs) {
            HStack(spacing: Spacing.chair.sm) {
                AvatarView(name: invite.ownerHandle, size: 40)
                VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                    Text("@\(invite.ownerHandle) linked you to a match")
                        .chairFont(.headline)
                        .foregroundStyle(Color.chair.ink)
                    Text(Self.detail(invite))
                        .chairFont(.callout)
                        .foregroundStyle(Color.chair.inkSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: Spacing.chair.sm) {
                ChairButton("Accept", onTap: handleAccept(invite))
                    .accessibilityIdentifier("invites.accept.\(invite.matchID)")
                ChairButton("Decline", style: .secondary, onTap: handleDecline(invite))
                    .accessibilityIdentifier("invites.decline.\(invite.matchID)")
            }
        }
        .padding(.vertical, Spacing.chair.xs)
    }

    static func detail(_ invite: Invite) -> String {
        let date = invite.playedAt.formatted(date: .abbreviated, time: .omitted)
        let format = invite.format == .doubles ? "Doubles" : "Singles"
        let sets = invite.sets.map { "\($0.a)–\($0.b)" }.joined(separator: " ")
        let score = invite.status == .inProgress ? (sets.isEmpty ? "In progress" : "\(sets) so far") : sets
        return [date, format, score].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func handleDone() -> () -> Void {
        { dismiss() }
    }

    private func handleRefresh() -> @MainActor @Sendable () async -> Void {
        { [center] in await center.refresh() }
    }

    private func handleAccept(_ invite: Invite) -> () -> Void {
        { [center] in Task { await center.accept(invite) } }
    }

    private func handleDecline(_ invite: Invite) -> () -> Void {
        { [center] in Task { await center.decline(invite) } }
    }
}

struct InvitesBanner: View {
    let center: InviteCenter

    var body: some View {
        if !center.invites.isEmpty {
            Button(action: handleOpen()) {
                HStack(spacing: Spacing.chair.xs) {
                    Label(center.bannerText, systemImage: "person.badge.plus")
                        .chairFont(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(Font.chair.callout.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .padding(Spacing.chair.md)
                .frame(minHeight: 56)
            }
            .buttonStyle(ChairButtonStyle(.ghost))
            .accessibilityIdentifier("invites.banner")
        }
    }

    private func handleOpen() -> () -> Void {
        { [center] in center.isShowingInvites = true }
    }
}
