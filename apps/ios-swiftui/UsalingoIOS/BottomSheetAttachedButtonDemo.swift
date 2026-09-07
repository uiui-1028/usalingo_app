//
//  Untitled.swift
//  UsalingoIOS
//
//  Created by Art 0 on 2026/09/07.
//

import SwiftUI

struct BottomSheetAttachedButtonDemo: View {
    // 0 = Large, 1 = Medium
    @State private var selectedDetent: Detent = .medium
    @GestureState private var dragTranslation: CGFloat = 0
    
    private enum Detent {
        case large
        case medium
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            
            // シート上端の位置
            let largeY: CGFloat = 150
            let mediumY: CGFloat = screenHeight * 0.48
            
            let baseY = selectedDetent == .large ? largeY : mediumY
            
            // ドラッグ中だけ指に追従
            let currentY = max(
                largeY,
                min(mediumY + 80, baseY + dragTranslation)
            )
            
            ZStack(alignment: .top) {
                // 背景
                Color(red: 1.0, green: 0.34, blue: 0.60)
                    .ignoresSafeArea()
                
                // 説明用タイトル
                VStack(spacing: 8) {
                    Text("Background")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                    
                    Text("シートとボタンを同じ親コンテナで動かす")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 40)
                
                // ボタン + シート
                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        print("Start tapped")
                    } label: {
                        Text("始める")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 180, height: 54)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.32, green: 0.43, blue: 1.0))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(.black.opacity(0.8), lineWidth: 1.5)
                            )
                    }
                    .padding(.trailing, 18)
                    
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(red: 0.32, green: 0.43, blue: 1.0))
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(.white.opacity(0.45))
                                .frame(width: 44, height: 5)
                                .padding(.top, 10)
                        }
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Bottom Sheet")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                
                                Text("上下にドラッグしてください")
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            .padding(.top, 34)
                            .padding(.horizontal, 24)
                        }
                        .frame(
                            width: max(0, geometry.size.width - 24),
                            height: screenHeight
                        )
                }
                .offset(y: currentY)
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .updating($dragTranslation) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            let predicted = baseY + value.predictedEndTranslation.height
                            let threshold = (largeY + mediumY) / 2
                            
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                selectedDetent = predicted < threshold ? .large : .medium
                            }
                        }
                )
                .animation(
                    .spring(response: 0.38, dampingFraction: 0.82),
                    value: selectedDetent
                )
            }
        }
    }
}

#Preview("Attached Button Bottom Sheet") {
    BottomSheetAttachedButtonDemo()
}
