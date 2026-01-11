//
//  ErrorView.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-11.
//

import SwiftUI

/// Reusable error view with consistent styling and retry action
struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?
    
    init(error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }
    
    private var networkError: NetworkError? {
        error as? NetworkError
    }
    
    private var icon: String {
        networkError?.icon ?? "exclamationmark.triangle.fill"
    }
    
    private var title: String {
        networkError?.errorDescription ?? "Error"
    }
    
    private var message: String {
        networkError?.recoverySuggestion ?? error.localizedDescription
    }
    
    private var isRetryable: Bool {
        networkError?.isRetryable ?? true
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let retryAction = retryAction, isRetryable {
                Button {
                    retryAction()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.primary)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Compact inline error view for smaller spaces
struct CompactErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?
    
    private var networkError: NetworkError? {
        error as? NetworkError
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: networkError?.icon ?? "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(networkError?.errorDescription ?? "Error")
                    .font(.subheadline.weight(.medium))
                
                Text(networkError?.recoverySuggestion ?? error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if let retryAction = retryAction {
                Button {
                    retryAction()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.medium))
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

#Preview("Full Error View") {
    ErrorView(
        error: NetworkError.networkUnavailable,
        retryAction: { print("Retry") }
    )
}

#Preview("Compact Error View") {
    CompactErrorView(
        error: NetworkError.unauthorized,
        retryAction: { print("Retry") }
    )
}
