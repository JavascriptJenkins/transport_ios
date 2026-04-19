//
//  LoginView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/2/26.
//

import SwiftUI

// MARK: - Login View
struct LoginView: View {

    @EnvironmentObject var authService: AuthService

    @State private var tenantInput = ""
    @State private var tenantError: String?
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var animateGradient = false
    @State private var totpCode = ""
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case tenant, username, password
    }

    /// True when we should show the tenant picker — i.e. multi-tenant mode
    /// is active AND no tenant has been selected yet.
    private var needsTenantSelection: Bool {
        authService.isMultiTenant && authService.selectedTenant == nil
    }

    var body: some View {
        ZStack {
            // MARK: - Animated Dark Background
            backgroundGradient

            // MARK: - Floating Orbs (ambient depth)
            floatingOrbs

            // MARK: - Main Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    Spacer().frame(height: 60)

                    // Logo
                    logoSection

                    // Glassmorphic Card
                    glassCard

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 28)
            }
        }
        .ignoresSafeArea(.all, edges: .all)
        .sheet(isPresented: Binding(
            get: { authService.pendingMFAToken != nil },
            set: { if !$0 { authService.cancelMFAChallenge() } }
        )) {
            totpSheet
                .presentationDetents([.medium])
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }

    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.12),
                Color(red: 0.08, green: 0.06, blue: 0.18),
                Color(red: 0.04, green: 0.04, blue: 0.10)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Floating Orbs
    private var floatingOrbs: some View {
        GeometryReader { geo in
            // Top-right orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.3, green: 0.2, blue: 0.6).opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(
                    x: animateGradient ? geo.size.width * 0.4 : geo.size.width * 0.5,
                    y: animateGradient ? -40 : -20
                )

            // Bottom-left orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.15, green: 0.15, blue: 0.35).opacity(0.35),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 350, height: 350)
                .offset(
                    x: animateGradient ? -80 : -40,
                    y: animateGradient ? geo.size.height * 0.55 : geo.size.height * 0.6
                )
        }
        .ignoresSafeArea()
    }

    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 16) {
            Image("BuneLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.white.opacity(0.08), radius: 20, x: 0, y: 10)

            Text("BUNE")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .tracking(6)

            if let tenant = authService.selectedTenant {
                HStack(spacing: 8) {
                    Text(tenant.displayName.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.white.opacity(0.7))
                        .tracking(2)
                    Button {
                        authService.clearTenantAndLogout()
                        tenantInput = ""
                        username = ""
                        password = ""
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                }
                Text("Sign in to continue")
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.5))
            } else if needsTenantSelection {
                Text("Enter your tenant to continue")
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.5))
            } else {
                Text("Sign in to continue")
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.5))
            }
        }
    }

    // MARK: - Glass Card
    private var glassCard: some View {
        VStack(spacing: 22) {
            if needsTenantSelection {
                tenantCardContent
            } else {
                credentialsCardContent
            }
        }
        .padding(28)
        .background(glassBackground)
    }

    // MARK: - Tenant Card Content
    @ViewBuilder
    private var tenantCardContent: some View {
        glassTextField(
            icon: "building.2.fill",
            placeholder: "Tenant name",
            text: $tenantInput,
            field: .tenant
        )
        .onChange(of: tenantInput) { _, _ in
            if tenantError != nil {
                withAnimation { tenantError = nil }
            }
        }

        if let error = tenantError {
            Text(error)
                .font(.caption)
                .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                .multilineTextAlignment(.center)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }

        continueButton
    }

    // MARK: - Credentials Card Content
    @ViewBuilder
    private var credentialsCardContent: some View {
        glassTextField(
            icon: "person.fill",
            placeholder: "Username",
            text: $username,
            field: .username
        )

        glassPasswordField

        if let error = authService.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                .multilineTextAlignment(.center)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }

        loginButton

        dividerRow

        Button {
            // TODO: Implement forgot password flow
        } label: {
            Text("Forgot password?")
                .font(.footnote)
                .foregroundColor(Color.white.opacity(0.45))
        }
    }

    // MARK: - Glass Background
    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial)
            .opacity(0.55)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
    }

    // MARK: - Glass Text Field
    private func glassTextField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(Color.white.opacity(0.5))
                .frame(width: 20)

            TextField("", text: text, prompt: Text(placeholder).foregroundColor(Color.white.opacity(0.35)))
                .foregroundColor(.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($focusedField, equals: field)
                .submitLabel(field == .username ? .next : .go)
                .onSubmit {
                    switch field {
                    case .tenant:
                        attemptTenantSelection()
                    case .username:
                        focusedField = .password
                    case .password:
                        attemptLogin()
                    }
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            focusedField == field
                                ? Color.white.opacity(0.25)
                                : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Password Field
    private var glassPasswordField: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .foregroundColor(Color.white.opacity(0.5))
                .frame(width: 20)

            Group {
                if showPassword {
                    TextField("", text: $password, prompt: Text("Password").foregroundColor(Color.white.opacity(0.35)))
                } else {
                    SecureField("", text: $password, prompt: Text("Password").foregroundColor(Color.white.opacity(0.35)))
                }
            }
            .foregroundColor(.white)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit { attemptLogin() }

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(Color.white.opacity(0.35))
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            focusedField == .password
                                ? Color.white.opacity(0.25)
                                : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Continue Button (tenant step)
    private var continueButton: some View {
        Button(action: attemptTenantSelection) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.25, blue: 0.65),
                                Color(red: 0.25, green: 0.18, blue: 0.50)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 52)
                    .shadow(color: Color(red: 0.3, green: 0.2, blue: 0.6).opacity(0.4), radius: 12, y: 6)

                Text("Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(1)
            }
        }
        .disabled(tenantInput.trimmingCharacters(in: .whitespaces).isEmpty)
        .opacity(tenantInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
        .padding(.top, 4)
    }

    // MARK: - Login Button
    private var loginButton: some View {
        Button(action: attemptLogin) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.25, blue: 0.65),
                                Color(red: 0.25, green: 0.18, blue: 0.50)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 52)
                    .shadow(color: Color(red: 0.3, green: 0.2, blue: 0.6).opacity(0.4), radius: 12, y: 6)

                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign In")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(1)
                }
            }
        }
        .disabled(authService.isLoading || username.isEmpty || password.isEmpty)
        .opacity(username.isEmpty || password.isEmpty ? 0.5 : 1.0)
        .padding(.top, 4)
    }

    // MARK: - Divider
    private var dividerRow: some View {
        HStack {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
            Text("or")
                .font(.caption2)
                .foregroundColor(Color.white.opacity(0.3))
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
        }
    }

    // MARK: - Login Action
    private func attemptLogin() {
        guard !username.isEmpty, !password.isEmpty else { return }
        focusedField = nil
        Task {
            await authService.login(username: username, password: password)
        }
    }

    // MARK: - TOTP Sheet
    private var totpSheet: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36))
                    .foregroundColor(BuneColors.accentPrimary)
                Text("Two-Factor Verification")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(BuneColors.textPrimary)
                Text("We sent a 6-digit code to your email. Enter it below to finish signing in.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(BuneColors.textSecondary)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 20)

            TextField("", text: $totpCode,
                      prompt: Text("123456").foregroundColor(BuneColors.textTertiary))
                .keyboardType(.numberPad)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundColor(BuneColors.textPrimary)
                .padding(.vertical, 10)
                .frame(maxWidth: 220)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BuneColors.glassFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(BuneColors.glassBorder, lineWidth: 1)
                        )
                )

            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
            }

            Button {
                Task {
                    await authService.submitTOTPCode(totpCode)
                    if authService.pendingMFAToken == nil {
                        totpCode = ""
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.35, green: 0.25, blue: 0.65),
                                    Color(red: 0.25, green: 0.18, blue: 0.50)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 48)
                    if authService.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Verify")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .tracking(1)
                    }
                }
            }
            .padding(.horizontal, 28)
            .disabled(totpCode.count < 6 || authService.isLoading)
            .opacity(totpCode.count < 6 || authService.isLoading ? 0.6 : 1.0)

            Button("Cancel") {
                totpCode = ""
                authService.cancelMFAChallenge()
            }
            .font(.footnote)
            .foregroundColor(BuneColors.textSecondary)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BuneColors.backgroundPrimary)
    }

    // MARK: - Tenant Selection Action
    private func attemptTenantSelection() {
        let trimmed = tenantInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard let tenant = Config.tenant(matching: trimmed) else {
            withAnimation {
                tenantError = "Unknown tenant. Check the name and try again."
            }
            return
        }
        tenantError = nil
        authService.selectTenant(tenant)
        // After selection, jump focus to the username field on the next step.
        DispatchQueue.main.async {
            focusedField = .username
        }
    }
}

// MARK: - Preview
#Preview {
    LoginView()
        .environmentObject(AuthService())
}
