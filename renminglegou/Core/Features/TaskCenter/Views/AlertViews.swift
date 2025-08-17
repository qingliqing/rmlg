//
//  AlertViews.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI

// MARK: - Service Charge Alert
struct ServiceChargeAlertView: View {
    let orderAmount: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("温馨提示")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Content with highlighted amount
            VStack(spacing: 8) {
                Text("调起第三方认证接口费用需花费")
                    .foregroundColor(.secondary)
                    .font(.body)
                + Text(" \(orderAmount)元")
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
                    .font(.body)
            }
            .multilineTextAlignment(.center)
            
            // Buttons
            HStack(spacing: 12) {
                Button("取消") {
                    onCancel()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("去支付") {
                    onConfirm()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Alipay Verification Alert
struct AlipayVerifyAlertView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("前往第三方人脸认证")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Content
            Text("亲亲，系统检测您还未前往第三方人脸认证，需要认证之后，才可以领取奖励噢~")
                .foregroundColor(.secondary)
                .font(.body)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            
            // Buttons
            HStack(spacing: 12) {
                Button("知道了") {
                    onCancel()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("前往认证") {
                    onConfirm()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Success Alert
struct SuccessAlertView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            // Title
            Text("成功")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Message
            Text(message)
                .foregroundColor(.secondary)
                .font(.body)
                .multilineTextAlignment(.center)
            
            // Dismiss Button
            Button("确定") {
                onDismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .frame(minWidth: 80, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.blue)
            .frame(minWidth: 80, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                    )
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
