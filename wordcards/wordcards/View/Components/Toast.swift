//
//  Toast.swift
//  wordcards
//
//  Created by k191k on 2022/04/30.
//

import SwiftUI
import ComposableArchitecture

struct ToastState: Equatable {
    var isShow = false
    var message: String
    var severity: Severity = .success
    
    enum Severity: Equatable {
        case error
        case success
        
        var color: Color {
            switch self {
            case .error: return .red
            case .success: return .cyan
            }
        }
        
        var image: Image {
            switch self {
            case .error: return Image(systemName: "exclamationmark.circle.fill")
            case .success: return Image(systemName: "checkmark.circle.fill")
            }
        }
    }
}

enum ToastAction: Equatable {
    case show(ToastState.Severity, String)
    case disappear
}

struct ToastEnvironment {
    var mainQueue: AnySchedulerOf<DispatchQueue>
}

let toastReducer = Reducer<ToastState, ToastAction, ToastEnvironment> {
    state, action, environment in
    
    struct TimerId: Hashable {}
    switch action {
    case let .show(severity, message):
        state.isShow = true
        state.message = message
        state.severity = severity
        return Effect.timer(
            id: TimerId(),
            every: 1.5,
            on: environment.mainQueue.animation(.easeInOut)
        ).map { _ in ToastAction.disappear }
        
    case .disappear:
        state.isShow = false
        return Effect.cancel(id: TimerId())
    }
}

struct Toast: View {
    let store: Store<ToastState, ToastAction>
    var body: some View {
        WithViewStore(self.store) { viewStore in
            if viewStore.state.isShow {
                VStack {
                    HStack {
                        viewStore.state.severity.image
                        Text(viewStore.state.message)
                        Spacer()
                    }.foregroundColor(Color.white)
                        .padding()
                        .background(viewStore.state.severity.color)
                        .cornerRadius(8)
                    Spacer()
                }
                .padding()
                .animation(.easeInOut, value: viewStore.state.isShow)
                .onTapGesture {
                    withAnimation { viewStore.send(.disappear) }
                }
            }
        }
    }
}

struct Toast_Previews: PreviewProvider {
    static var previews: some View {
        Toast(store: Store(initialState: ToastState(isShow: true, message: "TEST MESSAGE"),
                           reducer: toastReducer,
                           environment: ToastEnvironment(mainQueue: .main)))
    }
}
