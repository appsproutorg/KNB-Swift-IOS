//
//  SiddurView.swift
//  KNB
//
//  Created by AI Assistant on 2/6/26.
//

import SwiftUI
import CoreLocation
import Combine

// MARK: - Prayer Section Model
struct PrayerSection: Identifiable {
    let id = UUID()
    let title: String
    let hebrewTitle: String
    let icon: String
    let color: Color
}

// MARK: - Siddur View
struct SiddurView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var showBenching = false
    @State private var showMincha = false
    @State private var showMaariv = false
    @State private var showTefillatHaDerech = false
    
    private var backgroundColor: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ?
                [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.1, green: 0.1, blue: 0.15)] :
                [Color(red: 0.98, green: 0.98, blue: 1.0), Color(red: 0.94, green: 0.96, blue: 1.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.blue.opacity(0.2),
                                                Color.purple.opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            VStack(spacing: 4) {
                                Text("סידור")
                                    .font(.system(size: 32, weight: .bold, design: .serif))
                                    .foregroundStyle(.primary)
                                
                                Text("Siddur")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                        
                        // Prayer Sections
                        VStack(spacing: 14) {
                            PrayerSectionCard(
                                title: "Benching",
                                hebrewTitle: "ברכת המזון",
                                icon: "fork.knife",
                                color: .orange
                            ) {
                                showBenching = true
                            }
                            
                            PrayerSectionCard(
                                title: "Mincha",
                                hebrewTitle: "מנחה",
                                icon: "sun.max.fill",
                                color: .blue
                            ) {
                                showMincha = true
                            }

                            PrayerSectionCard(
                                title: "Maariv",
                                hebrewTitle: "מעריב",
                                icon: "moon.stars.fill",
                                color: .indigo
                            ) {
                                showMaariv = true
                            }

                            PrayerSectionCard(
                                title: "Tefillat HaDerech",
                                hebrewTitle: "תפילת הדרך",
                                icon: "car.fill",
                                color: .teal
                            ) {
                                showTefillatHaDerech = true
                            }

                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Siddur")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showBenching) {
                BenchingView()
            }
            .sheet(isPresented: $showMincha) {
                MinchaView()
            }
            .sheet(isPresented: $showMaariv) {
                MaarivView()
            }
            .sheet(isPresented: $showTefillatHaDerech) {
                TefillatHaDerechView()
            }
        }
    }
}

private struct SiddurFontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var siddurFontScale: CGFloat {
        get { self[SiddurFontScaleKey.self] }
        set { self[SiddurFontScaleKey.self] = newValue }
    }
}

struct TextSizeControl: View {
    @Binding var textScale: Double
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Button {
                textScale = max(0.85, textScale - 0.05)
            } label: {
                Text("A-")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }

            Button {
                textScale = min(1.6, textScale + 0.05)
            } label: {
                Text("A+")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
        }
        .foregroundStyle(.primary)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.25) : Color(red: 0.92, green: 0.92, blue: 0.95))
        )
    }
}

final class HeadingManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: CLLocationDirection = 0
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        // Fewer heading callbacks keeps UI smooth and lowers battery use.
        locationManager.headingFilter = 3
        authorizationStatus = locationManager.authorizationStatus
    }

    func start() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        guard CLLocationManager.headingAvailable() else { return }
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingHeading()
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            start()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let trueHeading = newHeading.trueHeading
        heading = trueHeading >= 0 ? trueHeading : newHeading.magneticHeading
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }

    func stop() {
        locationManager.stopUpdatingHeading()
    }
}

struct EastCompassBadge: View {
    @StateObject private var headingManager = HeadingManager()

    private var eastRotation: Double {
        // Snap to whole degrees to avoid unnecessary redraw churn.
        (90 - headingManager.heading).rounded()
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .rotationEffect(.degrees(eastRotation))
                .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.82), value: eastRotation)

            Text("מזרח")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: 64, height: 64)
        .background(
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.6), Color.white.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 4)
        .onAppear {
            headingManager.start()
        }
        .onDisappear {
            headingManager.stop()
        }
        .accessibilityLabel("Compass pointing East")
    }
}

// MARK: - Prayer Section Card
struct PrayerSectionCard: View {
    let title: String
    let hebrewTitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.2),
                                    color.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text(hebrewTitle)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.2) : .white)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 10, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.1 : 0.5),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Benching View
struct BenchingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showEnglish: Bool = false
    @AppStorage("siddurTextScale") private var textScale: Double = 1.0
    
    private var backgroundColor: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ?
                [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.1, green: 0.1, blue: 0.15)] :
                [Color(red: 0.98, green: 0.98, blue: 1.0), Color(red: 0.94, green: 0.96, blue: 1.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 8) {
                            Text("ברכת המזון")
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundStyle(.primary)
                            
                            Text("Birkat Hamazon")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                        
                        // English Toggle - Segmented Style
                        HStack(spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showEnglish = false
                                }
                            } label: {
                                Text("עברית")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(!showEnglish ? .white : .primary)
                                    .frame(width: 80, height: 36)
                                    .background(
                                        Capsule()
                                            .fill(!showEnglish ? Color.blue : Color.clear)
                                    )
                            }
                            
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showEnglish = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("עב")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("+")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("En")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(showEnglish ? .white : .primary)
                                .frame(width: 80, height: 36)
                                .background(
                                    Capsule()
                                        .fill(showEnglish ? Color.blue : Color.clear)
                                )
                            }
                        }
                        .padding(4)
                        .background(
                            Capsule()
                                .fill(colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.25) : Color(red: 0.92, green: 0.92, blue: 0.95))
                        )
                        .padding(.bottom, 10)

                        TextSizeControl(textScale: $textScale)
                            .padding(.bottom, 20)
                        
                        // Prayer Content
                        VStack(alignment: .leading, spacing: 0) {
                            // Shir Hamaalos
                            PrayerBlock(
                                hebrew: "שִׁיר הַמַּעֲלוֹת בְּשׁוּב יְהֹוָה אֶת־שִׁיבַת צִיּוֹן הָיִֽינוּ כְּחֹלְ֒מִים: אָז יִמָּלֵא שְׂחוֹק פִּֽינוּ וּלְשׁוֹנֵֽנוּ רִנָּה, אָז יֹאמְ֒רוּ בַגּוֹיִם הִגְדִּיל יְהֹוָה לַעֲשׂוֹת עִם־אֵֽלֶּה: הִגְדִּיל יְהֹוָה לַעֲשׂוֹת עִמָּֽנוּ, הָיִֽינוּ שְׂמֵחִים: שׁוּבָה יְהֹוָה אֶת־שְׁבִיתֵֽנוּ כַּאֲפִיקִים בַּנֶּֽגֶב: הַזֹּרְ֒עִים בְּדִמְעָה, בְּרִנָּה יִקְצֹֽרוּ: הָלוֹךְ יֵלֵךְ וּבָכֹה, נֹשֵׂא מֶֽשֶׁךְ־הַזָּֽרַע, בֹּא־יָבֹא בְרִנָּה, נֹשֵׂא אֲלֻמֹּתָיו:",
                                english: "A Song of Ascents. When Adonoy brings about the return to Zion we will have been like dreamers. Then will our mouths be filled with laughter, and our tongue with joyous song. Then will they say among the nations: 'Adonoy has done great things for them.' Adonoy had done great things for us; we will [then] rejoice. Adonoy! bring back our exiles like springs in the desert. Those who sow in tears will reap with joyous song. [Though] he walks along weeping, carrying the bag of seed, he will return with joyous song carrying his sheaves.",
                                showEnglish: showEnglish
                            )
                            
                            // Zimun Introduction
                            InstructionText(text: "When three or more males, aged 13 or older eat together one of them leads the group in reciting the Birkas Hamazon.", showEnglish: showEnglish)
                            
                            InstructionText(text: "The leader begins by saying:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "רַבּוֹתַי נְבָרֵךְ:",
                                english: "\"Gentlemen, let us say the blessing:\"",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "The others respond:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "יְהִי שֵׁם יְהֹוָה מְבֹרָךְ מֵעַתָּה וְעַד־עוֹלָם:",
                                english: "The Name of Adonoy will be blessed from now forever.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "The leader repeats:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "יְהִי שֵׁם יְהֹוָה מְבֹרָךְ מֵעַתָּה וְעַד־עוֹלָם:",
                                english: "\"The Name of Adonoy will be blessed from now forever.\"",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "The leader continues (the words \"our God\" are substituted for \"Him\" and \"He\" if ten males are in the group):", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "בִּרְשׁוּת מָרָנָן וְרַבָּנָן וְרַבּוֹתַי נְבָרֵךְ (בעשרה אֱלֺהֵֽינוּ) שֶׁאָכַֽלְנוּ מִשֶּׁלּוֹ:",
                                english: "\"With your permission our masters and teachers, Let us bless (our God,) Him, for we have eaten of His bounty.\"",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "The others respond accordingly:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "בָּרוּךְ (בעשרה אֱלֺהֵֽינוּ) שֶֽׁאָכַֽלְנוּ מִשֶּׁלּוֹ וּבְטוּבוֹ חָיִֽינוּ:",
                                english: "Blessed is (our God) He for we have eaten of His bounty and through His goodness we live.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "One who did not eat, responds:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "בָּרוּךְ (בעשרה או יותר אֱלֹהֵינוּ) וּמְבוֹרָךְ שְׁמוֹ תָּמִיד לְעוֹלָם וָעֶד:",
                                english: "Blessed is (our God) He, and His Name constantly, forever and ever.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "The leader repeats:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "בָּרוּךְ (בעשרה אֱלֺהֵֽינוּ) שֶֽׁאָכַֽלְנוּ מִשֶּׁלּוֹ וּבְטוּבוֹ חָיִֽינוּ:",
                                english: "\"Blessed is (our God) He for we have eaten of His bounty and through His goodness we live.\"",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "Some add: Blessed is He and blessed is His Name.", showEnglish: showEnglish)
                            
                            // First Beracha
                            SectionHeader(title: "FIRST BERACHA")
                            
                            PrayerBlock(
                                hebrew: "בָּרוּךְ אַתָּה יְהֹוָה אֱלֺהֵֽינוּ מֶֽלֶךְ הָעוֹלָם הַזָּן אֶת־הָעוֹלָם כֻּלּוֹ בְּטוּבוֹ בְּחֵן בְּחֶֽסֶד וּבְרַחֲמִים הוּא נוֹתֵן לֶֽחֶם לְכָל־בָּשָׂר כִּי לְעוֹלָם חַסְדּוֹ וּבְטוּבוֹ הַגָּדוֹל תָּמִיד לֺא־חָסַר לָֽנוּ וְאַל־יֶחְסַר לָֽנוּ מָזוֹן לְעוֹלָם וָעֶד בַּעֲבוּר שְׁמוֹ הַגָּדוֹל כִּי הוּא אֵל זָן וּמְפַרְנֵס לַכֹּל וּמֵטִיב לַכֹּל וּמֵכִין מָזוֹן לְכָל־בְּרִיּוֹתָיו אֲשֶׁר בָּרָא: בָּרוּךְ אַתָּה יְהֹוָה הַזָּן אֶת־הַכֹּל:",
                                english: "Blessed are You, Adonoy our God, King of the Universe, Who nourishes the entire world with His goodness, with favor, with kindness, and with mercy. He provides food for all flesh, for His kindness endures forever. And through His great goodness, we have never lacked and we will not lack food forever and ever, for the sake of His great Name. For He is Almighty Who nourishes and maintains all, does good to all, and prepares nourishment for all His creatures which He has created. Blessed are You, Adonoy Who nourishes all.",
                                showEnglish: showEnglish
                            )
                            
                            // Second Beracha
                            SectionHeader(title: "SECOND BERACHA")
                            
                            PrayerBlock(
                                hebrew: "נוֹדֶה לְּךָ יְהֹוָה אֱלֺהֵֽינוּ עַל שֶׁהִנְחַֽלְתָּ לַאֲבוֹתֵֽינוּ אֶֽרֶץ חֶמְדָּה טוֹבָה וּרְחָבָה וְעַל שֶׁהוֹצֵאתָֽנוּ יְהֹוָה אֱלֺהֵֽינוּ מֵאֶֽרֶץ מִצְרַֽיִם וּפְדִיתָֽנוּ מִבֵּית עֲבָדִים וְעַל בְּרִיתְ֒ךָ שֶׁחָתַֽמְתָּ בִּבְשָׂרֵֽנוּ וְעַל תּוֹרָתְ֒ךָ שֶׁלִּמַּדְתָּֽנוּ וְעַל חֻקֶּֽיךָ שֶׁהוֹדַעְתָּֽנוּ וְעַל חַיִּים חֵן וָחֶֽסֶד שֶׁחוֹנַנְתָּֽנוּ וְעַל אֲכִילַת מָזוֹן שָׁאַתָּה זָן וּמְפַרְנֵס אוֹתָֽנוּ תָּמִיד בְּכָל־יוֹם וּבְכָל־עֵת וּבְכָל שָׁעָה:",
                                english: "We thank You, Adonoy, our God, for Your parceling out as a heritage to our fathers, a land which is desirable, good, and spacious; for Your bringing us out, Adonoy, our God, from the land of Egypt, and redeeming us from the house of bondage; for Your covenant which You sealed in our flesh; for Your Torah which You taught us; for Your statutes which You made known to us; for the life, favor, and kindness which You granted us; and for the provision of food with which You nourish and maintain us constantly, every day, at all times and in every hour.",
                                showEnglish: showEnglish
                            )
                            
                            // Al Hanisim section
                            InstructionText(text: "On Chanukah and Purim add:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "וְעַל הַנִּסִּים וְעַל הַפֻּרְקָן וְעַל הַגְּ֒בוּרוֹת וְעַל הַתְּ֒שׁוּעוֹת וְעַל הַמִּלְחָמוֹת שֶׁעָשִֽׂיתָ לַאֲבוֹתֵֽינוּ בַּיָּמִים הָהֵם בִּזְּ֒מַן הַזֶּה:",
                                english: "[We thank You] for the miracles for the redemption, for the mighty deeds, for the deliverances, for the wonders for the consolations and for the wars that You performed for our fathers in those days at this season.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "On Chanukah:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "בִּימֵי מַתִּתְיָֽהוּ בֶּן־יוֹחָנָן כֹּהֵן גָּדוֹל חַשְׁמוֹנַאי וּבָנָיו כְּשֶׁעָמְ֒דָה מַלְכוּת יָוָן הָרְ֒שָׁעָה עַל־עַמְּ֒ךָ יִשְׂרָאֵל לְהַשְׁכִּיחָם תּוֹרָתֶֽךָ וּלְהַעֲבִירָם מֵחֻקֵּי רְצוֹנֶֽךָ: וְאַתָּה בְּרַחֲמֶֽיךָ הָרַבִּים עָמַֽדְתָּ לָהֶם בְּעֵת צָרָתָם רַֽבְתָּ אֶת־רִיבָם דַּֽנְתָּ אֶת־דִּינָם נָקַֽמְתָּ אֶת־נִקְמָתָם מָסַֽרְתָּ גִבּוֹרִים בְּיַד חַלָּשִׁים וְרַבִּים בְּיַד מְעַטִּים וּטְמֵאִים בְּיַד טְהוֹרִים וּרְשָׁעִים בְּיַד צַדִּיקִים וְזֵדִים בְּיַד עוֹסְ֒קֵי תוֹרָתֶֽךָ וּלְךָ עָשִֽׂיתָ שֵׁם גָּדוֹל וְקָדוֹשׁ בְּעוֹלָמֶֽךָ וּלְעַמְּ֒ךָ יִשְׂרָאֵל עָשִֽׂיתָ תְּשׁוּעָה גְדוֹלָה וּפֻרְקָן כְּהַיּוֹם הַזֶּה וְאַחַר כַּךְ בָּֽאוּ בָנֶֽיךָ לִדְבִיר בֵּיתֶֽךָ וּפִנּוּ אֶת הֵיכָלֶֽךָ וְטִהֲרוּ אֶת מִקְדָּשֶֽׁךָ וְהִדְלִֽיקוּ נֵרוֹת בְּחַצְרוֹת קָדְשֶֽׁךָ וְקָבְ֒עוּ שְׁמוֹנַת יְמֵי חֲנֻכָּה אֵֽלּוּ לְהוֹדוֹת וּלְהַלֵּל לְשִׁמְךָ הַגָּדוֹל:",
                                english: "In the days of Matisyahu, son of Yochanan the High Priest, the Hasmonean and his sons, when the evil Greek kingdom rose up against Your people Israel to make them forget Your Torah and to turn them away from the statutes of Your will— You, in Your abundant mercy, stood by them in their time of distress, You defended their cause, You judged their grievances, You avenged them. You delivered the mighty into the hands of the weak, many into the hands of the few, defiled people into the hands of the undefiled, the wicked into the hands of the righteous, and insolent [sinners] into the hands of diligent students of Your Torah. And You made Yourself a great and sanctified name in Your world. And for Your people, Israel, You performed a great deliverance and redemption unto this very day. Afterwards, Your sons entered the Holy of Holies of Your Abode, cleaned Your Temple, purified Your Sanctuary, and kindled lights in the Courtyards of Your Sanctuary, and designated these eight days of Chanukah to thank and praise Your great Name.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "On Purim:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "בִּימֵי מָרְדְּכַי וְאֶסְתֵּר בְּשׁוּשַׁן הַבִּירָה כְּשֶׁעָמַד עֲלֵיהֶם הָמָן הָרָשָׁע בִּקֵּשׁ לְהַשְׁמִיד לַהֲרוֹג וּלְאַבֵּד אֶת־כָּל־הַיְּהוּדִים מִנַּֽעַר וְעַד־זָקֵן טַף וְנָשִׁים בְּיוֹם אֶחָד בִּשְׁלוֹשָׁה עָשָׂר לְחֹֽדֶשׁ שְׁנֵים־עָשָׂר הוּא חֹֽדֶשׁ אֲדָר וּשְׁלָלָם לָבוֹז: וְאַתָּה בְּרַחֲמֶֽיךָ הָרַבִּים הֵפַֽרְתָּ אֶת־עֲצָתוֹ וְקִלְקַֽלְתָּ אֶת מַחֲשַׁבְתּוֹ וַהֲשֵׁבֽוֹתָ לּוֹ גְּמוּלוֹ בְּרֹאשׁוֹ וְתָלוּ אוֹתוֹ וְאֶת־בָּנָיו עַל־הָעֵץ:",
                                english: "In the days of Mordechai and Esther in Shushan the Capital [of Persia], when the evil Haman rose up against them, he sought to destroy, to kill, and to annihilate all the Jews, young and old, infants and women, in one day, the thirteenth day of the twelfth month, which is the month of Adar, and to plunder their wealth And You, in Your abundant mercy, annulled his counsel, frustrated his intention, and brought his evil plan upon his own head, and they hanged him and his sons upon the gallows.",
                                showEnglish: showEnglish
                            )
                            
                            // Continue Second Beracha
                            PrayerBlock(
                                hebrew: "וְעַל הַכֹּל יְהֹוָה אֱלֺהֵֽינוּ אֲנַֽחְנוּ מוֹדִים לָךְ וּמְבָרְ֒כִים אוֹתָךְ יִתְבָּרַךְ שִׁמְךָ בְּפִי כָּל־חַי תָּמִיד לְעוֹלָם וָעֶד כַּכָּתוּב וְאָכַלְתָּ וְשָׂבָֽעְתָּ וּבֵרַכְתָּ אֶת־יְהֹוָה אֱלֺהֶֽיךָ עַל־הָאָֽרֶץ הַטּוֹבָה אֲשֶׁר נָתַן־לָךְ בָּרוּךְ אַתָּה יְהֹוָה עַל־הָאָֽרֶץ וְעַל־הַמָּזוֹן:",
                                english: "For everything Adonoy, our God, We thank You and bless You. Blessed be Your Name through the mouth of all the living, constantly, forever, as it is written: When You have eaten and are satisfied, You will bless Adonoy, your God, for the good land which He has given to you. Blessed are You, Adonoy, for the land and for the food.",
                                showEnglish: showEnglish
                            )
                            
                            // Third Beracha
                            SectionHeader(title: "THIRD BERACHA")
                            
                            PrayerBlock(
                                hebrew: "רַחֵם יְהֹוָה אֱלֺהֵֽינוּ עַל־יִשְׂרָאֵל עַמֶּֽךָ וְעַל יְרוּשָׁלַֽיִם עִירֶֽךָ וְעַל צִיּוֹן מִשְׁכַּן כְּבוֹדֶֽךָ וְעַל מַלְכוּת בֵּית דָּוִד מְשִׁיחֶֽךָ וְעַל־הַבַּֽיִת הַגָּדוֹל וְהַקָּדוֹשׁ שֶׁנִּקְרָא שִׁמְךָ עָלָיו אֱלֺהֵֽינוּ אָבִֽינוּ רְעֵֽנוּ זוּנֵֽנוּ פַּרְנְ֒סֵֽנוּ וְכַלְכְּ֒לֵֽנוּ וְהַרְוִיחֵֽנוּ וְהַרְוַח־לָֽנוּ יְהֹוָה אֱלֺהֵֽינוּ מְהֵרָה מִכָּל־צָרוֹתֵֽינוּ וְנָא אַל־תַּצְרִיכֵֽנוּ יְהֹוָה אֱלֺהֵֽינוּ לֺא לִידֵי מַתְּ֒נַת בָּשָׂר וָדָם וְלֺא לִידֵי הַלְוָאָתָם כִּי אִם לְיָדְ֒ךָ הַמְּלֵאָה הַפְּ֒תוּחָה הַקְּ֒דוֹשָׁה וְהָרְ֒חָבָה שֶׁלֺּא נֵבוֹשׁ וְלֺא נִכָּלֵם לְעוֹלָם וָעֶד:",
                                english: "Have compassion, Adonoy, our God, on Israel, Your people, on Jerusalem, Your city, on Zion, the dwelling place of Your glory, on the kingship of the house of David, Your anointed; and on the great and holy House upon which Your Name is called. Our God, our Father tend us, nourish us, maintain us, sustain us, relieve us and grant us relief Adonoy, our God, speedily from all our troubles. Adonoy, our God—may we never be in need of the gifts of men nor of their loans, but only of Your hand which is full, open, holy and generous, so that we may not be shamed nor humiliated forever and ever.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "On Shabbos add:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "רְצֵה וְהַחֲלִיצֵֽנוּ יְהֹוָה אֱלֺהֵֽינוּ בְּמִצְוֹתֶֽיךָ וּבְמִצְוַת יוֹם הַשְּׁ֒בִיעִי הַשַּׁבָּת הַגָּדוֹל וְהַקָּדוֹשׁ הַזֶּה כִּי יוֹם זֶה גָדוֹל וְקָדוֹשׁ הוּא לְפָנֶֽיךָ לִשְׁבָּת בּוֹ וְלָנֽוּחַ בּוֹ בְּאַהֲבָה כְּמִצְוַת רְצוֹנֶֽךָ וּבִרְצוֹנְ֒ךָ הָנִֽיחַ לָֽנוּ יְהֹוָה אֱלֺהֵֽינוּ שֶׁלֺּא תְהֵא צָרָה וְיָגוֹן וַאֲנָחָה בְּיוֹם מְנוּחָתֵֽנוּ וְהַרְאֵֽנוּ יְהֹוָה אֱלֺהֵֽינוּ בְּנֶחָמַת צִיּוֹן עִירֶֽךָ וּבְבִנְיַן יְרוּשָׁלַֽיִם עִיר קָדְשֶֽׁךָ כִּי אַתָּה הוּא בַּעַל הַיְשׁוּעוֹת וּבַעַל הַנֶּחָמוֹת:",
                                english: "May it please You, to strengthen us Adonoy, our God, through Your commandments, and through the commandment of the seventh day, this great and holy Sabbath. For this day is great and holy before You, to refrain from work on it and to rest on it with love, as ordained by Your will. And by Your will, grant us repose Adonoy, our God, that there be no distress, sorrow, or sighing on the day of our rest. Show us Adonoy, our God, the consolation of Zion, Your city, and the rebuilding of Jerusalem, city of Your Sanctuary, for You are the Master of deliverance and the Master of consolation.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "On Rosh Chodesh and Yom Tov add:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "אֱלֹהֵֽינוּ וֵאלֹהֵי אֲבוֹתֵֽינוּ יַעֲלֶה וְיָבֹא וְיַגִּֽיעַ וְיֵרָאֶה וְיֵרָצֶה וְיִשָּׁמַע וְיִפָּקֵד וְיִזָּכֵר זִכְרוֹנֵֽנוּ וּפִקְדוֹנֵֽנוּ וְזִכְרוֹן אֲבוֹתֵֽינוּ וְזִכְרוֹן מָשִֽׁיחַ בֶּן־דָּוִד עַבְדֶּֽךָ וְזִכְרוֹן יְרוּשָׁלַֽיִם עִיר קָדְשֶֽׁךָ וְזִכְרוֹן כָּל־עַמְּ֒ךָ בֵּית יִשְׂרָאֵל לְפָנֶֽיךָ, לִפְלֵיטָה לְטוֹבָה לְחֵן וּלְחֶֽסֶד וּלְרַחֲמִים לְחַיִּים וּלְשָׁלוֹם בְּיוֹם",
                                english: "Our God and God of our fathers, may there ascend, come, and reach, appear, be desired, and heard, counted and recalled our remembrance and reckoning; the remembrance of our fathers; the remembrance of the Messiah the son of David, Your servant; the remembrance of Jerusalem, city of Your Sanctuary; and the remembrance of Your entire people, the House of Israel, before You for survival, for well-being, for favor, kindliness, compassion, for life and peace on this day of:",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "Rosh Chodesh • the Festival of Matzos • the Festival of Sukkos • the Festival of Shmini Atseres • Remembrance", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "זָכְרֵֽנוּ יְהֹוָה אֱלֹהֵֽינוּ בּוֹ לְטוֹבָה, וּפָקְדֵֽנוּ בוֹ לִבְרָכָה, וְהוֹשִׁיעֵֽנוּ בוֹ לְחַיִּים, וּבִדְבַר יְשׁוּעָה וְרַחֲמִים חוּס וְחָנֵּֽנוּ, וְרַחֵם עָלֵֽינוּ וְהוֹשִׁיעֵֽנוּ, כִּי אֵלֶֽיךָ עֵינֵֽינוּ, כִּי אֵל מֶֽלֶךְ חַנּוּן וְרַחוּם אָֽתָּה:",
                                english: "Remember us Adonoy, our God, on this day for well-being; be mindful of us on this day for blessing, and deliver us for life. In accord with the promise of deliverance and compassion, spare us and favor us, have compassion on us and deliver us; for to You our eyes are directed because You are the Almighty Who is King, Gracious, and Merciful.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "וּבְנֵה יְרוּשָׁלַֽיִם עִיר הַקֹּֽדֶשׁ בִּמְהֵרָה בְיָמֵֽינוּ: בָּרוּךְ אַתָּה יְהֹוָה בּוֹנֵה בְרַחֲמָיו יְרוּשָׁלָֽיִם, אָמֵן:",
                                english: "Rebuild Jerusalem, city of the Holy Sanctuary, speedily, in our days. Blessed are You, Adonoy, Builder of Jerusalem in His mercy. Amein.",
                                showEnglish: showEnglish
                            )
                            
                            // Fourth Beracha
                            SectionHeader(title: "FOURTH BERACHA")
                            
                            PrayerBlock(
                                hebrew: "בָּרוּךְ אַתָּה יְהֹוָה אֱלֺהֵֽינוּ מֶֽלֶךְ הָעוֹלָם, הָאֵל אָבִֽינוּ, מַלְכֵּֽנוּ, אַדִּירֵֽנוּ בּוֹרְ֒אֵֽנוּ, גּוֹאֲלֵֽנוּ, יוֹצְ֒רֵֽנוּ, קְדוֹשֵֽׁנוּ קְדוֹשׁ יַעֲקֹב, רוֹעֵנוּ רוֹעֵה יִשְׂרָאֵל, הַמֶּֽלֶךְ הַטּוֹב, וְהַמֵּטִיב לַכֹּל, שֶׁבְּ֒כָל יוֹם וָיוֹם הוּא הֵטִיב, הוּא מֵטִיב, הוּא יֵיטִיב לָנוּ, הוּא גְמָלָֽנוּ, הוּא גוֹמְ֒לֵֽנוּ, הוּא יִגְמְ֒לֵֽנוּ לָעַד לְחֵן וּלְחֶֽסֶד וּלְרַחֲמִים וּלְרֶוַח הַצָּלָה וְהַצְלָחָה בְּרָכָה וִישׁוּעָה, נֶחָמָה, פַּרְנָסָה וְכַלְכָּלָה, וְרַחֲמִים, וְחַיִּים וְשָׁלוֹם, וְכָל־טוֹב, וּמִכָּל־טוּב לְעוֹלָם אַל יְחַסְּ֒רֵֽנוּ:",
                                english: "Blessed are You, Adonoy our God, King of the Universe, the Almighty, our Father, our King, our Mighty One, our Creator, our Redeemer, our Maker, our Holy One, Holy One of Jacob, our Shepherd, Shepherd of Israel, the King, Who is good and beneficent to all. Every single day He has done good, does good, and will do good to us. He has rewarded us, He rewards us, He will reward us forever with favor, kindness, and compassion, relief, rescue, and success, blessing, deliverance, and consolation, maintenance, sustenance, compassion, life, peace, and everything good; and of all good things may He never deprive us.",
                                showEnglish: showEnglish
                            )
                            
                            // Harachaman prayers
                            SectionHeader(title: "HARACHAMAN")
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יִמְלוֹךְ עָלֵֽינוּ לְעוֹלָם וָעֶד:",
                                english: "The Merciful One will reign over us forever and ever.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יִתְבָּרַךְ בַּשָּׁמַֽיִם וּבָאָֽרֶץ:",
                                english: "The Merciful One will be blessed in heaven and on earth.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יִשְׁתַּבַּח לְדוֹר דּוֹרִים, וְיִתְפָּאַר בָּֽנוּ לָעַד וּלְנֵֽצַח נְצָחִים, וְיִתְהַדַּר בָּֽנוּ לָעַד וּלְעוֹלְ֒מֵי עוֹלָמִים:",
                                english: "The Merciful One will be praised for all generations, He will be glorified through us forever and for all eternity; and He will be honored through us for time everlasting.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יְפַרְנְ֒סֵֽנוּ בְּכָבוֹד:",
                                english: "May the Merciful One maintain us with honor.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יִשְׁבּוֹר עֻלֵּֽנוּ מֵעַל צַוָּארֵֽנוּ וְהוּא יוֹלִיכֵֽנוּ קוֹמְ֒מִיּוּת לְאַרְצֵֽנוּ:",
                                english: "The Merciful One will break the yoke (of oppression) from our necks and lead us upright to our land.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יִשְׁלַח לָֽנוּ בְּרָכָה מְרֻבָּה בַּבַּֽיִת הַזֶּה וְעַל־שֻׁלְחָן זֶה שֶׁאָכַֽלְנוּ עָלָיו:",
                                english: "May the Merciful One send us abundant blessing to this house, and upon this table at which we have eaten.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יִשְׁלַח לָֽנוּ אֶת־אֵלִיָּֽהוּ הַנָּבִיא זָכוּר לַטּוֹב, וִיבַשֶּׂר־לָֽנוּ בְּשׂוֹרוֹת טוֹבוֹת יְשׁוּעוֹת וְנֶחָמוֹת:",
                                english: "The Merciful One will send us Elijah the prophet, who is remembered for good, who will announce to us good tidings, deliverances, and consolations.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "When eating at your parents' table, say:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יְבָרֵךְ אֶת־(אָבִי מוֹרִי) בַּֽעַל הַבַּֽיִת הַזֶּה, וְאֶת־(אִמִּי מוֹרָתִי) בַּעֲלַת הַבַּֽיִת הַזֶּה, אוֹתָם וְאֶת־בֵּיתָם וְאֶת־זַרְעָם וְאֶת־כָּל־אֲשֶׁר לָהֶם",
                                english: "May the Merciful One bless my father, my teacher, the master of this house, and my mother, my teacher, the mistress of this house; them, their household, their children and all that is theirs.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "When eating at your own table, say:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יְבָרֵךְ אוֹתִי (וְאֶת־אִשְׁתִּי/בַּעֲלִי וְאֶת־זַרְעִי) וְאֶת־כָּל־אֲשֶׁר לִי.",
                                english: "May the Merciful One bless me, my spouse, my children, and all that is mine;",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "אוֹתָֽנוּ וְאֶת־כָּל־אֲשֶׁר לָֽנוּ, כְּמוֹ שֶׁנִּתְבָּרְ֒כוּ אֲבוֹתֵֽינוּ, אַבְרָהָם יִצְחָק וְיַעֲקֹב: בַּכֹּל, מִכֹּל, כֹּל, כֵּן יְבָרֵךְ אוֹתָֽנוּ כֻּלָּֽנוּ יַֽחַד, בִּבְרָכָה שְׁלֵמָה, וְנֹאמַר אָמֵן:",
                                english: "Ours and all that is ours— just as our forefathers were blessed— Abraham, Isaac, and Jacob— In all things, \"From everything,\" and \"With everything\"; so may He bless us, all of us together, with a perfect blessing and let us say Amein.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "A guest says:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "יְהִי רָצוֹן שֶׁלֹּא יֵבוֹשׁ וְלֹא יִכָּלֵם בַּעַל הַבַּֽיִת הַזֶּה לֹא בָעוֹלָם הַזֶּה וְלֹא בָעוֹלָם הַבָּא וְיַצְלִֽיחַ בְּכָל־נְכָסָיו וְיִהְיוּ נְכָסָיו מוּצְלָחִים וּקְרוֹבִים לָעִיר וְאַל־יִשְׁלוֹט שָׂטָן בְּמַעֲשֵׂה יָדָיו וְאַל יִזְדָקֵּק לְפָנָיו שׁוּם דְּבַר חֵטְא וְהַרְהוֹר עָוֹן מַעַתָּה וְעַד עוֹלָם:",
                                english: "May it be God's will that the host should not be shamed and not humiliated not in this world nor in the World to Come. And he will be successful with all his possessions. May his properties prosper and be located close to town. May no evil force have power over his endeavors. May no opportunity present itself before him any matter of sin, nor thought of iniquity from now forever.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "בַּמָּרוֹם יְלַמְּ֒דוּ עֲלֵיהֶם וְעָלֵֽינוּ זְכוּת שֶׁתְּ֒הֵא לְמִשְׁמֶֽרֶת שָׁלוֹם, וְנִשָּׂא בְרָכָה מֵאֵת יְהֹוָה וּצְדָקָה מֵאֱלֺהֵי יִשְׁעֵֽנוּ, וְנִמְצָא חֵן וְשֵֽׂכֶל טוֹב בְּעֵינֵי אֱלֺהִים וְאָדָם:",
                                english: "From on high, may there be invoked upon them and upon us, [the] merit to insure peace, And may we receive a blessing from Adonoy, and kindness from the God of our deliverance; and may we find favor and understanding in the eyes of God and man.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "On Shabbos say:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יַנְחִילֵֽנוּ יוֹם שֶׁכֻּלּוֹ שַׁבָּת וּמְנוּחָה לְחַיֵּי הָעוֹלָמִים:",
                                english: "May the Merciful One let us inherit the day which will be completely Shabbos and rest, for life everlasting.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "On Rosh Chodesh say:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יְחַדֵּשׁ עָלֵֽינוּ אֶת הַחֹֽדֶשׁ הַזֶּה לְטוֹבָה וְלִבְרָכָה:",
                                english: "May the Merciful One renew for us this month for good and for blessing.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "On Yom Tov say:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יַנְחִילֵֽנוּ יוֹם שֶׁכֻּלּוֹ טוֹב:",
                                english: "May the Merciful One let us inherit that day which is completely good.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "On Rosh Hashono say:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יְחַדֵּשׁ עָלֵֽינוּ אֶת הַשָּׁנָה הַזֹּאת לְטוֹבָה וְלִבְרָכָה:",
                                english: "May the Merciful One renew for us this year for good and for blessing.",
                                showEnglish: showEnglish
                            )
                            
                            InstructionText(text: "On Sukkos say:", showEnglish: showEnglish)
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יָקִים לָֽנוּ אֶת־סֻכַּת דָּוִד הַנּוֹפָֽלֶת:",
                                english: "May the Merciful One raise up for us the fallen Tabernacle of David.",
                                showEnglish: showEnglish
                            )
                            
                            // Conclusion
                            SectionHeader(title: "CONCLUSION")
                            
                            PrayerBlock(
                                hebrew: "הָרַחֲמָן הוּא יְזַכֵּֽנוּ לִימוֹת הַמָּשִֽׁיחַ וּלְחַיֵּי הָעוֹלָם הַבָּא, מַגְדִּיל יְשׁוּעוֹת מַלְכּוֹ (בשבת וביו״ט: מִגְדּוֹל יְשׁוּעוֹת מַלְכּוֹ), וְעֹֽשֶׂה חֶֽסֶד לִמְשִׁיחוֹ לְדָוִד וּלְזַרְעוֹ עַד עוֹלָם: עֹשֶׂה שָׁלוֹם בִּמְרוֹמָיו, הוּא יַעֲשֶׂה שָׁלוֹם עָלֵֽינוּ וְעַל כָּל־יִשְׂרָאֵל, וְאִמְרוּ אָמֵן:",
                                english: "May the Merciful One make us worthy of the days of the Messiah and life of the World to Come. He who gives great deliverance to His king, (On Shabbos and Yom Tov say: He who is a tower of deliverance to His king,) and shows kindness to His anointed— to David and his descendants forever. He Who makes peace in His high heavens may He make peace for us and for all Israel, and say, Amein.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "יְראוּ אֶת־יְהֹוָה קְדוֹשָׁיו, כִּי אֵין מַחְסוֹר לִירֵאָיו: כְּפִירִים רָשׁוּ וְרָעֵֽבוּ, וְדוֹרְ֒שֵׁי יְהֹוָה לֺא־יַחְסְ֒רוּ כָל־טוֹב: הוֹדוּ לַיהוָֹה כִּי־טוֹב, כִּי לְעוֹלָם חַסְדּוֹ: פּוֹתֵֽחַ אֶת־יָדֶֽךָ, וּמַשְׂבִּֽיעַ לְכָל־חַי רָצוֹן: בָּרוּךְ הַגֶּֽבֶר אֲשֶׁר יִבְטַח בַּיהוָֹה, וְהָיָה יְהֹוָה מִבְטַחוֹ: נַֽעַר הָיִֽיתִי גַם־זָקַֽנְתִּי וְלֺא־רָאִֽיתִי צַדִּיק נֶעֱזָב, וְזַרְעוֹ מְבַקֶּשׁ־לָֽחֶם: יְהֹוָה עוֹז לְעַמּוֹ יִתֵּן, יְהֹוָה יְבָרֵךְ אֶת־עַמּוֹ בַּשָּׁלוֹם:",
                                english: "Fear Adonoy, [you] His holy ones, for those who fear Him suffer no deprivation. Young lions may feel want and hunger, but those who seek Adonoy, will not be deprived of any good thing. Give thanks to Adonoy, for He is good, for His kindness endures forever. You open Your hand and satisfy the desire of every living being. Blessed is the man who trusts in Adonoy, so that Adonoy is his security. I was young and I have grown old, yet I have never seen a righteous man forsaken, nor his children begging for bread. Adonoy will give strength to His people, Adonoy will bless His people with peace.",
                                showEnglish: showEnglish
                            )
                        }
                        .environment(\.siddurFontScale, CGFloat(textScale))
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.2) : .white)
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 15, x: 0, y: 4)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }

            }
            .navigationTitle("Benching")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

// MARK: - Prayer Block
struct PrayerBlock: View {
    let hebrew: String
    let english: String
    let showEnglish: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.siddurFontScale) var fontScale
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Hebrew
            Text(hebrew)
                .font(.system(size: 20 * fontScale, weight: .regular, design: .serif))
                .multilineTextAlignment(.trailing)
                .lineSpacing(8)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            // English (only shown when toggle is on)
            if showEnglish {
                Text(english)
                    .font(.system(size: 16 * fontScale, weight: .regular, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 16)
        .padding(.bottom, 8)
        .overlay(
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                .frame(height: 1),
            alignment: .bottom
        )
        .animation(.easeInOut(duration: 0.2), value: showEnglish)
    }
}

// MARK: - Instruction Text
struct InstructionText: View {
    let text: String
    let showEnglish: Bool
    @Environment(\.siddurFontScale) var fontScale
    
    var body: some View {
        if showEnglish {
            Text(text)
                .font(.system(size: 14 * fontScale, weight: .medium, design: .rounded))
                .foregroundStyle(.orange)
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.siddurFontScale) var fontScale
    
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .blue.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 2)
            
            Text(title)
                .font(.system(size: 13 * fontScale, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
                .tracking(0.5)
                .fixedSize(horizontal: true, vertical: false)
            
            Rectangle()
                .fill(LinearGradient(colors: [.blue.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 2)
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Tefillat HaDerech View
struct TefillatHaDerechView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showEnglish: Bool = false
    @AppStorage("siddurTextScale") private var textScale: Double = 1.0

    private var backgroundColor: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ?
                [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.1, green: 0.1, blue: 0.15)] :
                [Color(red: 0.98, green: 0.98, blue: 1.0), Color(red: 0.94, green: 0.96, blue: 1.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                backgroundColor.ignoresSafeArea()

                ScrollView(showsIndicators: true) {
                    VStack(spacing: 0) {
                        VStack(spacing: 8) {
                            Text("תפילת הדרך")
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundStyle(.primary)

                            Text("Tefillat HaDerech")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 20)

                        HStack(spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showEnglish = false
                                }
                            } label: {
                                Text("עברית")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(!showEnglish ? .white : .primary)
                                    .frame(width: 80, height: 36)
                                    .background(
                                        Capsule()
                                            .fill(!showEnglish ? Color.blue : Color.clear)
                                    )
                            }

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showEnglish = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("עב")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("+")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("En")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(showEnglish ? .white : .primary)
                                .frame(width: 80, height: 36)
                                .background(
                                    Capsule()
                                        .fill(showEnglish ? Color.blue : Color.clear)
                                )
                            }
                        }
                        .padding(4)
                        .background(
                            Capsule()
                                .fill(colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.25) : Color(red: 0.92, green: 0.92, blue: 0.95))
                        )
                        .padding(.bottom, 10)

                        TextSizeControl(textScale: $textScale)
                            .padding(.bottom, 20)

                        VStack(alignment: .leading, spacing: 0) {
                            PrayerBlock(
                                hebrew: "יְהִי רָצוֹן מִלְפָנֶיךָ יי אֱלֹהֵינוּ וֵאלֹהֵי אֲבוֹתֵינוּ, שֶׁתּוֹלִיכֵנוּ לְשָׁלוֹם וְתַצְעִידֵנוּ לְשָׁלוֹם וְתַדְרִיכֵנוּ לְשָׁלוֹם, וְתִסְמְכֵנוּ לְשָׁלוֹם, וְתַגִּיעֵנוּ לִמְחוֹז חֶפְצֵנוּ לְחַיִּים וּלְשִׂמְחָה וּלְשָׁלוֹם. (אם דעתו לחזור מיד אומר וְתַחְזִירֵנוּ לְשָׁלוֹם) וְתַצִּילֵנוּ מִכַּף כָּל אוֹיֵב וְאוֹרֵב וְלִסְטִים וְחַיּוֹת רָעוֹת בַּדֶּרֶךְ, וּמִכָּל מִינֵי פֻּרְעָנֻיּוֹת הַמִּתְרַגְּשׁוֹת לָבוֹא לָעוֹלָם, וְתִתְּנֵנוּ לְחֵן וּלְחֶסֶד וּלְרַחֲמִים בְּעֵינֶיךָ וּבְעֵינֵי כָל רֹאֵינוּ, כִּי אל שׁוֹמֵעַ תְּפִלָּה וְתַחֲנוּן אַתָּה. בָּרוּךְ אַתָּה לפי נוסח ספרד יי שׁוֹמֵעַ תְּפִלָּה:",
                                english: "May it be Your will, Eternal One, our God and the God of our ancestors, that You lead us toward peace, support our footsteps towards peace, guide us toward peace, and make us reach our desired destination, for life, joy, and peace. May You rescue us from the hand of every foe, ambush, bandits and wild animals along the way, and from all manner of punishments that assemble to come to Earth. May You send blessing in our every handiwork, and grant us peace, kindness, and mercy in your eyes and in the eyes of all who see us. May You hear the sound of our supplication, because You are the God who hears prayer and supplications. Blessed are You, Eternal One, who hears prayer.",
                                showEnglish: showEnglish
                            )
                        }
                        .environment(\.siddurFontScale, CGFloat(textScale))
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.2) : .white)
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 15, x: 0, y: 4)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Tefillat HaDerech")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

// MARK: - Mincha View
struct MinchaView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showEnglish: Bool = false
    @AppStorage("siddurTextScale") private var textScale: Double = 1.0
    
    private var backgroundColor: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ?
                [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.1, green: 0.1, blue: 0.15)] :
                [Color(red: 0.98, green: 0.98, blue: 1.0), Color(red: 0.94, green: 0.96, blue: 1.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 8) {
                            Text("מנחה")
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundStyle(.primary)
                            
                            Text("Mincha")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                        
                        // Language Toggle
                        HStack(spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showEnglish = false
                                }
                            } label: {
                                Text("עברית")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(!showEnglish ? .white : .primary)
                                    .frame(width: 80, height: 36)
                                    .background(
                                        Capsule()
                                            .fill(!showEnglish ? Color.blue : Color.clear)
                                    )
                            }
                            
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showEnglish = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("עב")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("+")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("En")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(showEnglish ? .white : .primary)
                                .frame(width: 80, height: 36)
                                .background(
                                    Capsule()
                                        .fill(showEnglish ? Color.blue : Color.clear)
                                )
                            }
                        }
                        .padding(4)
                        .background(
                            Capsule()
                                .fill(colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.25) : Color(red: 0.92, green: 0.92, blue: 0.95))
                        )
                        .padding(.bottom, 10)

                        TextSizeControl(textScale: $textScale)
                            .padding(.bottom, 20)
                        
                        // Prayer Content
                        VStack(alignment: .leading, spacing: 0) {
                            // Ashrei
                            PrayerBlock(
                                hebrew: "אַשְׁרֵי יוֹשְׁ֒בֵי בֵיתֶֽךָ עוֹד יְהַלְלֽוּךָ סֶּֽלָה: אַשְׁרֵי הָעָם שֶׁכָּֽכָה לּוֹ אַשְׁרֵי הָעָם שֶׁיְהֹוָה אֱלֹהָיו: תְּהִלָּה לְדָוִד אֲרוֹמִמְךָ אֱלוֹהַי הַמֶּֽלֶךְ וַאֲבָרְ֒כָה שִׁמְךָ לְעוֹלָם וָעֶד: בְּכָל־יוֹם אֲבָרְ֒כֶֽךָּ וַאֲהַלְלָה שִׁמְךָ לְעוֹלָם וָעֶד: גָּדוֹל יְהֹוָה וּמְהֻלָּל מְאֹד וְלִגְדֻלָּתוֹ אֵין חֵֽקֶר: דּוֹר לְדוֹר יְשַׁבַּח מַעֲשֶׂיךָ וּגְבוּרֹתֶֽיךָ יַגִּֽידוּ: הֲדַר כְּבוֹד הוֹדֶֽךָ וְדִבְרֵי נִפְלְ֒אֹתֶֽיךָ אָשִֽׂיחָה: וֶעֱזוּז נוֹרְ֒אֹתֶֽיךָ יֹאמֵרוּ וּגְדֻלָּתְ֒ךָ אֲסַפְּ֒רֶֽנָּה: זֵֽכֶר רַב־טוּבְ֒ךָ יַבִּֽיעוּ וְצִדְקָתְ֒ךָ יְרַנֵּֽנוּ: חַנּוּן וְרַחוּם יְהֹוָה אֶֽרֶךְ אַפַּֽיִם וּגְדָל־חָֽסֶד: טוֹב־יְהֹוָה לַכֹּל וְרַחֲמָיו עַל־כָּל־מַעֲשָׂיו: יוֹדֽוּךָ יְהֹוָה כָּל־מַעֲשֶֽׂיךָ וַחֲסִידֶֽיךָ יְבָרְ֒כֽוּכָה: כְּבוֹד מַלְכוּתְ֒ךָ יֹאמֵרוּ וּגְבוּרָתְ֒ךָ יְדַבֵּֽרוּ: לְהוֹדִֽיעַ לִבְנֵי הָאָדָם גְּבוּרֹתָיו וּכְבוֹד הֲדַר מַלְכוּתוֹ: מַלְכוּתְ֒ךָ מַלְכוּת כָּל־עֹלָמִים וּמֶמְשַׁלְתְּ֒ךָ בְּכָל־דּוֹר וָדֹר: סוֹמֵךְ יְהֹוָה לְכָל־הַנֹּפְ֒לִים וְזוֹקֵף לְכָל־הַכְּ֒פוּפִים: עֵינֵי־כֹל אֵלֶֽיךָ יְשַׂבֵּֽרוּ וְאַתָּה נוֹתֵן־לָהֶם אֶת־אָכְלָם בְּעִתּוֹ: פּוֹתֵֽחַ אֶת־יָדֶֽךָ וּמַשְׂבִּֽיעַ לְכָל־חַי רָצוֹן: צַדִּיק יְהֹוָה בְּכָל־דְּרָכָיו וְחָסִיד בְּכָל־מַעֲשָׂיו: קָרוֹב יְהֹוָה לְכָל־קֹרְ֒אָיו לְכֹל אֲשֶׁר יִקְרָאֻֽהוּ בֶאֱמֶת: רְצוֹן־יְרֵאָיו יַעֲשֶׂה וְאֶת־שַׁוְעָתָם יִשְׁמַע וְיוֹשִׁיעֵם: שׁוֹמֵר יְהֹוָה אֶת־כָּל־אֹהֲבָיו וְאֵת כָּל־הָרְ֒שָׁעִים יַשְׁמִיד: תְּהִלַּת יְהֹוָה יְדַבֶּר פִּי וִיבָרֵךְ כָּל־בָּשָׂר שֵׁם קָדְשׁוֹ לְעוֹלָם וָעֶד: וַאֲנַֽחְנוּ נְבָרֵךְ יָהּ מֵעַתָּה וְעַד־עוֹלָם הַלְ֒לוּיָהּ:",
                                english: "Fortunate are those who dwell in Your house; may they continue to praise You, Selah. Fortunate is the people whose lot is thus; fortunate is the people for whom Adonoy is their God. A praise by David! I will exalt You, my God, the King, and bless Your Name forever and ever. Every day I will bless You and extol Your Name forever and ever. Adonoy is great and highly extolled, and His greatness is unfathomable. One generation to another will praise Your works, and Your mighty acts they will declare. The splendor of Your glorious majesty, and the words of Your wonders I will speak. Of Your awesome might, they will speak, and Your greatness I will recount. Mention of Your bountifulness they will express, and in Your righteousness joyfully exult. Adonoy is gracious and merciful, slow to anger and great in kindliness. Adonoy is good to all, His mercy encompasses all His works. All Your works will thank You, Adonoy, and Your pious ones will bless You. Of the honor of Your kingship, they will speak, and Your might they will declare. To reveal to men His mighty acts, and the glorious splendor of His kingship. Your kingship is the kingship for all times, and Your dominion is in every generation. Adonoy supports all the fallen, and straightens all the bent. The eyes of all look expectantly to You, and You give them their food at its proper time. You open Your hand and satisfy the desire of every living being. Adonoy is just in all His ways and benevolent in all His deeds. Adonoy is near to all who call upon Him, to all who call upon Him in truth. The will of those who fear Him, He fulfills; He hears their cry and delivers them. Adonoy watches over all those who love Him, and will destroy all the wicked. Praise of Adonoy, my mouth will declare and all flesh will bless His holy Name forever and ever. And we will bless God from now forever. Praise God",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "כִּי שֵׁם יְהֹוָה אֶקְרָא הָבוּ גֹֽדֶל לֵאלֹהֵֽינוּ:",
                                english: "When I proclaim Adonoy's Name attribute greatness to our God.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "אֲדֹנָי שְׂפָתַי תִּפְתָּח וּפִי יַגִּיד תְּהִלָּתֶֽךָ:",
                                english: "My Master, open my lips, and my mouth will declare Your praise.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "בָּרוּךְ אַתָּה יְהֹוָה אֱלֹהֵֽינוּ וֵאלֹהֵי אֲבוֹתֵֽינוּ אֱלֹהֵי אַבְרָהָם אֱלֹהֵי יִצְחָק וֵאלֹהֵי יַעֲקֹב הָאֵל הַגָּדוֹל הַגִּבּוֹר וְהַנּוֹרָא אֵל עֶלְיוֹן גּוֹמֵל חֲסָדִים טוֹבִים וְקוֹנֵה הַכֹּל וְזוֹכֵר חַסְדֵי אָבוֹת וּמֵבִיא גוֹאֵל לִבְנֵי בְנֵיהֶם לְמַֽעַן שְׁמוֹ בְּאַהֲבָה:",
                                english: "Blessed are You, Adonoy, our God, and God of our fathers, God of Abraham, God of Isaac, and God of Jacob, the Almighty, the Great, the Powerful, the Awesome, most high Almighty, Who bestows beneficent kindness, Who possesses everything, Who remembers the piety of the Patriarchs, and Who brings a redeemer to their children's children, for the sake of His Name, with love.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "מֶֽלֶךְ עוֹזֵר וּמוֹשִֽׁיעַ וּמָגֵן: בָּרוּךְ אַתָּה יְהֹוָה מָגֵן אַבְרָהָם:",
                                english: "King, Helper, and Deliverer and Shield. Blessed are You, Adonoy, Shield of Abraham.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "אַתָּה גִבּוֹר לְעוֹלָם אֲדֹנָי מְחַיֶּה מֵתִים אַתָּה רַב לְהוֹשִֽׁיעַ:",
                                english: "You are mighty forever, my Master; You are the Resurrector of the dead the Powerful One to deliver us.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "מַשִּׁיב הָרֽוּחַ וּמוֹרִיד הַגֶּֽשֶׁם: מְכַלְכֵּל חַיִּים בְּחֶֽסֶד מְחַיֵּה מֵתִים בְּרַחֲמִים רַבִּים סוֹמֵךְ נוֹפְ֒לִים וְרוֹפֵא חוֹלִים וּמַתִּיר אֲסוּרִים וּמְקַיֵּם אֱמוּנָתוֹ לִישֵׁנֵי עָפָר, מִי כָמֽוֹךָ בַּֽעַל גְּבוּרוֹת וּמִי דּֽוֹמֶה לָּךְ מֶֽלֶךְ מֵמִית וּמְחַיֶּה וּמַצְמִֽיחַ יְשׁוּעָה:",
                                english: "Causer of the wind to blow and of the rain to fall. Sustainer of the living with kindliness, Resurrector of the dead with great mercy, Supporter of the fallen, and Healer of the sick, and Releaser of the imprisoned, and Fulfiller of His faithfulness to those who sleep in the dust. Who is like You, Master of mighty deeds, and who can be compared to You? King Who causes death and restores life, and causes deliverance to sprout forth.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "וְנֶאֱמָן אַתָּה לְהַחֲיוֹת מֵתִים: בָּרוּךְ אַתָּה יְהֹוָה מְחַיֵּה הַמֵּתִים:",
                                english: "And You are faithful to restore the dead to life. Blessed are You, Adonoy, Resurrector of the dead.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "אַתָּה קָדוֹשׁ וְשִׁמְךָ קָדוֹשׁ וּקְדוֹשִׁים בְּכָל־יוֹם יְהַלְ֒לֽוּךָ סֶּֽלָה. בָּרוּךְ אַתָּה יְהֹוָה הָאֵל הַקָּדוֹשׁ:",
                                english: "You are holy and Your Name is holy and holy beings praise You every day, forever. Blessed are You, Adonoy, the Almighty, the Holy One.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "אַתָּה חוֹנֵן לְאָדָם דַּֽעַת וּמְלַמֵּד לֶאֱנוֹשׁ בִּינָה: חָנֵּֽנוּ מֵאִתְּ֒ךָ דֵּעָה בִּינָה וְהַשְׂכֵּל: בָּרוּךְ אַתָּה יְהֹוָה חוֹנֵן הַדָּֽעַת:",
                                english: "You favor man with perception and teach mankind understanding. Grant us knowledge, understanding and intellect from You. Blessed are You, Adonoy, Grantor of perception.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "הֲשִׁיבֵֽנוּ אָבִֽינוּ לְתוֹרָתֶֽךָ וְקָרְ֒בֵֽנוּ מַלְכֵּֽנוּ לַעֲבוֹדָתֶֽךָ וְהַחֲזִירֵֽנוּ בִּתְשׁוּבָה שְׁלֵמָה לְפָנֶֽיךָ: בָּרוּךְ אַתָּה יְהֹוָה הָרוֹצֶה בִּתְשׁוּבָה:",
                                english: "Cause us to return, our Father, to Your Torah and bring us near, our King, to Your service; and bring us back in whole-hearted repentance before You Blessed are You, Adonoy, Who desires penitence.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "סְלַח לָֽנוּ אָבִֽינוּ כִּי חָטָֽאנוּ מְחַל לָֽנוּ מַלְכֵּֽנוּ כִּי פָשָֽׁעְנוּ כִּי מוֹחֵל וְסוֹלֵֽחַ אָֽתָּה: בָּרוּךְ אַתָּה יְהֹוָה חַנּוּן הַמַּרְבֶּה לִסְלֽוֹחַ:",
                                english: "Pardon us, our Father, for we have sinned, forgive us, our King, for we have transgressed; for You forgive and pardon. Blessed are You, Adonoy, Gracious One, Who pardons abundantly.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "רְאֵה בְעָנְיֵֽנוּ וְרִיבָה רִיבֵֽנוּ וּגְאָלֵֽנוּ מְהֵרָה לְמַֽעַן שְׁמֶֽךָ כִּי גּוֹאֵל חָזָק אָֽתָּה: בָּרוּךְ אַתָּה יְהֹוָה גּוֹאֵל יִשְׂרָאֵל:",
                                english: "Look upon our affliction, and defend our cause: and redeem us speedily for the sake of Your Name; because You are a Mighty Redeemer. Blessed are You, Adonoy, Redeemer of Israel.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "רְפָאֵֽנוּ יְהֹוָה וְנֵרָפֵא הוֹשִׁיעֵֽנוּ וְנִוָּשֵֽׁעָה כִּי תְהִלָּתֵֽנוּ אָֽתָּה וְהַעֲלֵה רְפוּאָה שְׁלֵמָה לְכָל מַכּוֹתֵֽינוּ כִּי אֵל מֶֽלֶךְ רוֹפֵא נֶאֱמָן וְרַחֲמָן אָֽתָּה: בָּרוּךְ אַתָּה יְהֹוָה רוֹפֵא חוֹלֵי עַמּוֹ יִשְׂרָאֵל:",
                                english: "Heal us, Adonoy, and we will be healed, deliver us and we will be delivered; for You are our praise. Grant a complete healing to all our affliction because You are the Almighty, King, Who is a faithful and merciful Healer. Blessed are You, Adonoy, Healer of the sick of His people Israel.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "בָּרֵךְ עָלֵֽינוּ יְהֹוָה אֱלֹהֵֽינוּ אֶת־הַשָּׁנָה הַזֹּאת וְאֶת־כָּל־מִינֵי תְבוּאָתָהּ לְטוֹבָה, וְתֵן בְּרָכָה / טַל וּמָטָר לִבְרָכָה עַל פְּנֵי הָאֲדָמָה וְשַׂבְּ֒עֵֽנוּ מִטּוּבֶֽךָ וּבָרֵךְ שְׁנָתֵֽנוּ כַּשָּׁנִים הַטּוֹבוֹת: בָּרוּךְ אַתָּה יְהֹוָה מְבָרֵךְ הַשָּׁנִים:",
                                english: "Bless for us, Adonoy our God, this year and all the varieties of its produce for good; and bestow blessing / dew and rain for a blessing upon the face of the earth; satisfy us from Your bounty and bless our year, like the good years. Blessed are You, Adonoy, Blesser of the years.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "תְּקַע בְּשׁוֹפָר גָּדוֹל לְחֵרוּתֵֽנוּ וְשָׂא נֵס לְקַבֵּץ גָּלֻיּוֹתֵֽינוּ וְקַבְּ֒צֵֽנוּ יַֽחַד מֵאַרְבַּע כַּנְפוֹת הָאָֽרֶץ: בָּרוּךְ אַתָּה יְהֹוָה מְקַבֵּץ נִדְחֵי עַמּוֹ יִשְׂרָאֵל:",
                                english: "Sound the great shofar for our liberty, and raise a banner to gather our exiles, and gather us together from the four corners of the earth. Blessed are You, Adonoy, Gatherer of the dispersed of His people Israel.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "הָשִֽׁיבָה שׁוֹפְ֒טֵֽינוּ כְּבָרִאשׁוֹנָה וְיוֹעֲצֵֽינוּ כְּבַתְּ֒חִלָּה וְהָסֵר מִמֶּֽנּוּ יָגוֹן וַאֲנָחָה וּמְלוֹךְ עָלֵֽינוּ אַתָּה יְהֹוָה לְבַדְּ֒ךָ בְּחֶֽסֶד וּבְרַחֲמִים וְצַדְּ֒קֵֽנוּ בַּמִשְׁפָּט: בָּרוּךְ אַתָּה יְהֹוָה מֶֽלֶךְ אֹהֵב צְדָקָה וּמִשְׁפָּט:",
                                english: "Restore our judges as before and our counselors as at first. Remove sorrow and sighing from us, and reign over us You, Adonoy, alone with kindness and compassion; and make us righteous with justice, Blessed are You, Adonoy, King, Lover of righteousness and justice.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "וְלַמַּלְשִׁינִים אַל תְּהִי תִקְוָה וְכָל הָרִשְׁעָה כְּרֶֽגַע תֹּאבֵד וְכָל אֹיְבֶֽיךָ מְהֵרָה יִכָּרֵֽתוּ וְהַזֵּדִים מְהֵרָה תְעַקֵּר וּתְשַׁבֵּר וּתְמַגֵּר וְתַכְנִֽיעַ בִּמְהֵרָה בְיָמֵֽינוּ: בָּרוּךְ אַתָּה יְהֹוָה שׁוֹבֵר אֹיְ֒בִים וּמַכְנִֽיעַ זֵדִים:",
                                english: "Let there be no hope for informers and may all wickedness instantly perish; may all the enemies of Your people be swiftly cut off, and may You quickly uproot, crush, rout and subdue the insolent, speedily in our days. Blessed are You, Adonoy, Crusher of enemies and Subduer of the insolent.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "עַל־הַצַּדִּיקִים וְעַל־הַחֲסִידִים וְעַל־זִקְנֵי עַמְּ֒ךָ בֵּית יִשְׂרָאֵל וְעַל פְּלֵיטַת סוֹפְ֒רֵיהֶם וְעַל גֵּרֵי הַצֶּֽדֶק וְעָלֵֽינוּ יֶהֱמוּ רַחֲמֶֽיךָ יְהֹוָה אֱלֹהֵֽינוּ וְתֵן שָׂכָר טוֹב לְכָל הַבּוֹטְ֒חִים בְּשִׁמְךָ בֶּאֱמֶת וְשִׂים חֶלְקֵֽנוּ עִמָּהֶם לְעוֹלָם וְלֹא נֵבוֹשׁ כִּי בְךָ בָּטָֽחְנוּ: בָּרוּךְ אַתָּה יְהֹוָה מִשְׁעָן וּמִבְטָח לַצַּדִּיקִים:",
                                english: "May Your mercy be aroused, Adonoy our God, upon the righteous, upon the pious, upon the elders of Your people, Israel, upon the remnant of their scholars, upon the true proselytes and upon us. Grant bountiful reward to all who trust in Your Name in truth; and place our lot among them, and may we never be put to shame, for we have put our trust in You. Blessed are You, Adonoy, Support and Trust of the righteous.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "וְלִירוּשָׁלַֽיִם עִירְ֒ךָ בְּרַחֲמִים תָּשׁוּב וְתִשְׁכּוֹן בְּתוֹכָהּ כַּאֲשֶׁר דִּבַּֽרְתָּ וּבְנֵה אוֹתָהּ בְּקָרוֹב בְּיָמֵֽינוּ בִּנְיַן עוֹלָם וְכִסֵּא דָוִד מְהֵרָה לְתוֹכָהּ תָּכִין: בָּרוּךְ אַתָּה יְהֹוָה בּוֹנֵה יְרוּשָׁלָֽיִם:",
                                english: "And return in mercy to Jerusalem, Your city, and dwell therein as You have spoken; and rebuild it soon, in our days, as an everlasting structure, and may You speedily establish the throne of David therein. Blessed are You, Adonoy, Builder of Jerusalem.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "אֶת־צֶֽמַח דָּוִד עַבְדְּ֒ךָ מְהֵרָה תַצְמִֽיחַ וְקַרְנוֹ תָּרוּם בִּישׁוּעָתֶֽךָ כִּי לִישׁוּעָתְ֒ךָ קִוִּֽינוּ כָּל הַיּוֹם: בָּרוּךְ אַתָּה יְהֹוָה מַצְמִֽיחַ קֶֽרֶן יְשׁוּעָה:",
                                english: "Speedily cause the sprout of David, Your servant, to flourish and exalt his power with Your deliverance. We hope all day for Your deliverance. Blessed are You, Adonoy, Who causes the power of salvation to sprout.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "שְׁמַע קוֹלֵֽנוּ יְהֹוָה אֱלֹהֵֽינוּ חוּס וְרַחֵם עָלֵֽינוּ וְקַבֵּל בְּרַחֲמִים וּבְרָצוֹן אֶת־תְּפִלָּתֵֽנוּ כִּי אֵל שׁוֹמֵֽעַ תְּפִלּוֹת וְתַחֲנוּנִים אָֽתָּה וּמִלְּפָנֶֽיךָ מַלְכֵּֽנוּ רֵיקָם אַל־תְּשִׁיבֵֽנוּ כִּי אַתָּה שׁוֹמֵֽעַ תְּפִלַּת עַמְּךָ יִשְׂרָאֵל בְּרַחֲמִים: בָּרוּךְ אַתָּה יְהֹוָה שׁוֹמֵֽעַ תְּפִלָּה:",
                                english: "Hear our voice, Adonoy, our God; spare us and have compassion on us, and accept our prayers compassionately and willingly, for You are Almighty Who hears prayers and supplications; and do not turn us away empty-handed from Your Presence, our King, for You hear the prayers of Your people, Israel, with compassion. Blessed are You, Adonoy, Who hears prayers.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "רְצֵה יְהֹוָה אֱלֹהֵֽינוּ בְּעַמְּ֒ךָ יִשְׂרָאֵל וּבִתְפִלָּתָם וְהָשֵׁב אֶת הָעֲבוֹדָה לִדְבִיר בֵּיתֶֽךָ וְאִשֵּׁי יִשְׂרָאֵל וּתְפִלָּתָם בְּאַהֲבָה תְקַבֵּל בְּרָצוֹן וּתְהִי לְרָצוֹן תָּמִיד עֲבוֹדַת יִשְׂרָאֵל עַמֶּֽךָ: וְתֶחֱזֶֽינָה עֵינֵֽינוּ בְּשׁוּבְ֒ךָ לְצִיּוֹן בְּרַחֲמִים: בָּרוּךְ אַתָּה יְהֹוָה הַמַּחֲזִיר שְׁכִינָתוֹ לְצִיּוֹן:",
                                english: "Be pleased, Adonoy, our God, with Your people, Israel, and their prayer; and restore the service to the Holy of Holies in Your abode, and the fire-offerings of Israel; and accept their prayer, lovingly and willingly. And may You always find pleasure with the service of Your people, Israel. And may our eyes behold Your merciful return to Zion. Blessed are You, Adonoy, Who returns His Divine Presence to Zion.",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "אֱלֹהֵֽינוּ וֵאלֹהֵי אֲבוֹתֵֽינוּ יַעֲלֶה וְיָבֹא וְיַגִּֽיעַ וְיֵרָאֶה וְיֵרָצֶה וְיִשָּׁמַע וְיִפָּקֵד וְיִזָּכֵר זִכְרוֹנֵֽנוּ וּפִקְדוֹנֵֽנוּ וְזִכְרוֹן אֲבוֹתֵֽינוּ וְזִכְרוֹן מָשִֽׁיחַ בֶּן דָּוִד עַבְדֶּֽךָ וְזִכְרוֹן יְרוּשָׁלַֽיִם עִיר קָדְשֶֽׁךָ וְזִכְרוֹן כָּל עַמְּ֒ךָ בֵּית יִשְׂרָאֵל לְפָנֶֽיךָ, לִפְלֵיטָה לְטוֹבָה לְחֵן וּלְחֶֽסֶד וּלְרַחֲמִים וּלְחַיִּים טוֹבִים וּלְשָׁלוֹם בְּיוֹם לר\"ח: רֹאשׁ הַחֹֽדֶשׁ הַזֶּה. לפסח: חַג הַמַּצּוֹת הַזֶּה. לסכות: חַג הַסֻּכּוֹת הַזֶּה. זָכְרֵֽנוּ יְהֹוָה אֱלֹהֵֽינוּ בּוֹ לְטוֹבָה, וּפָקְדֵֽנוּ בוֹ לִבְרָכָה, וְהוֹשִׁיעֵֽנוּ בוֹ לְחַיִּים טוֹבִים, וּבִדְבַר יְשׁוּעָה וְרַחֲמִים חוּס וְחָנֵּֽנוּ, וְרַחֵם עָלֵֽינוּ וְהוֹשִׁיעֵֽנוּ, כִּי אֵלֶֽיךָ עֵינֵֽינוּ, כִּי אֵל מֶֽלֶךְ חַנּוּן וְרַחוּם אָֽתָּה:",
                                english: "Our God and God of our fathers, may there ascend, come, and reach, appear, be desired, and heard, counted and recalled our remembrance and reckoning; the remembrance of our fathers; the remembrance of the Messiah the son of David, Your servant; the remembrance of Jerusalem, city of Your Sanctuary; and the remembrance of Your entire people, the House of Israel, before You for survival, for well-being, for favor, kindliness, compassion, for good life and peace on this day of: Rosh Chodesh: this Rosh Chodesh. Pesach: this Festival of Matzos. Sukkos: this Festival of Sukkos. Remember us, Adonoy our God, on this day for well-being; be mindful of us on this day for blessing; and deliver us for good life. In accord with the promise of deliverance and compassion, spare us and favor us, have compassion on us and deliver us; for our eyes are directed to You, because You are the Almighty Who is King, Gracious, and Merciful.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "מוֹדִים אֲנַֽחְנוּ לָךְ שָׁאַתָּה הוּא יְהֹוָה אֱלֹהֵֽינוּ וֵאלֹהֵי אֲבוֹתֵֽינוּ לְעוֹלָם וָעֶד צוּר חַיֵּֽינוּ מָגֵן יִשְׁעֵֽנוּ אַתָּה הוּא לְדוֹר וָדוֹר נֽוֹדֶה לְּךָ וּנְסַפֵּר תְּהִלָּתֶֽךָ עַל־חַיֵּֽינוּ הַמְּ֒סוּרִים בְּיָדֶֽךָ וְעַל נִשְׁמוֹתֵֽינוּ הַפְּ֒קוּדוֹת לָךְ וְעַל נִסֶּֽיךָ שֶׁבְּכָל יוֹם עִמָּֽנוּ וְעַל נִפְלְ֒אוֹתֶֽיךָ וְטוֹבוֹתֶֽיךָ שֶׁבְּ֒כָל עֵת עֶֽרֶב וָבֹֽקֶר וְצָהֳרָֽיִם הַטּוֹב כִּי לֹא כָלוּ רַחֲמֶֽיךָ וְהַמְ֒רַחֵם כִּי לֹא תַֽמּוּ חֲסָדֶֽיךָ מֵעוֹלָם קִוִּֽינוּ לָךְ:",
                                english: "We are thankful to You that You Adonoy are our God and the God of our fathers forever; Rock of our lives, You are the Shield of our deliverance in every generation. We will give thanks to You and recount Your praise, for our lives which are committed into Your hand, and for our souls which are entrusted to You, and for Your miracles of every day with us, and for Your wonders and benefactions at all times— evening, morning and noon. (You are) The Beneficent One— for Your compassion is never withheld; And (You are) the Merciful One— for Your kindliness never ceases; we have always placed our hope in You.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "וְעַל־כֻּלָּם יִתְבָּרַךְ וְיִתְרוֹמַם שִׁמְךָ מַלְכֵּֽנוּ תָּמִיד לְעוֹלָם וָעֶד: וְכֹל הַחַיִּים יוֹדֽוּךָ סֶּֽלָה וִיהַלְ֒לוּ אֶת־שִׁמְךָ בֶּאֱמֶת הָאֵל יְשׁוּעָתֵֽנוּ וְעֶזְרָתֵֽנוּ סֶֽלָה: בָּרוּךְ אַתָּה יְהֹוָה הַטּוֹב שִׁמְךָ וּלְךָ נָאֶה לְהוֹדוֹת:",
                                english: "And for all the foregoing may Your Name, our King, constantly be blessed and extolled, forever and ever. And all the living shall thank You forever and praise Your Name with sincerity — the Almighty, Who is our deliverance and our help forever. Blessed are You, Adonoy; Your Name is The Beneficent and You it is fitting to praise.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "שָׁלוֹם רָב עַל יִשְׂרָאֵל עַמְּ֒ךָ תָּשִׂים לְעוֹלָם כִּי אַתָּה הוּא מֶֽלֶךְ אָדוֹן לְכָל־הַשָּׁלוֹם וְטוֹב בְּעֵינֶֽיךָ לְבָרֵךְ אֶת־עַמְּ֒ךָ יִשְׂרָאֵל בְּכָל־עֵת וּבְכָל־שָׁעָה בִּשְׁלוֹמֶֽךָ: בָּרוּךְ אַתָּה יְהֹוָה הַמְבָרֵךְ אֶת־עַמּוֹ יִשְׂרָאֵל בַּשָּׁלוֹם:",
                                english: "Bestow abundant peace upon Israel, Your people, forever. For You are King, the Master of all peace. And may it be good in Your sight to bless us and to bless Your people Israel, at all times and at every moment with Your peace. Blessed are You, Adonoy, Who blesses His people Israel with peace.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "יִהְיוּ לְרָצוֹן אִמְרֵי פִי וְהֶגְיוֹן לִבִּי לְפָנֶֽיךָ יְהֹוָה צוּרִי וְגוֹאֲלִי:",
                                english: "May the words of my mouth and the thoughts of my heart be acceptable before You, Adonoy, my Rock and my Redeemer.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "אֱלֹהַי נְצוֹר לְשׁוֹנִי מֵרָע וּשְׂפָתַי מִדַּבֵּר מִרְמָה. וְלִמְקַלְ֒לַי נַפְשִׁי תִדּוֹם וְנַפְשִׁי כֶּעָפָר לַכֹּל תִּהְיֶה. פְּתַח לִבִּי בְּתוֹרָתֶֽךָ וּבְמִצְוֹתֶֽיךָ תִּרְדֹּף נַפְשִׁי. וְכֹל הַחוֹשְׁ֒בִים עָלַי רָעָה מְהֵרָה הָפֵר עֲצָתָם וְקַלְקֵל מַחֲשַׁבְתָּם: עֲשֵׂה לְמַֽעַן שְׁמֶֽךָ עֲשֵׂה לְמַֽעַן יְמִינֶֽךָ עֲשֵׂה לְמַֽעַן קְדֻשָּׁתֶֽךָ עֲשֵׂה לְמַֽעַן תּוֹרָתֶֽךָ. לְמַֽעַן יֵחָלְ֒צוּן יְדִידֶֽיךָ הוֹשִֽׁיעָה יְמִינְ֒ךָ וַעֲנֵֽנִי: יִהְיוּ לְרָצוֹן אִמְרֵי פִי וְהֶגְיוֹן לִבִּי לְפָנֶֽיךָ יְהֹוָה צוּרִי וְגוֹאֲלִי: עֹשֶׂה שָׁלוֹם בִּמְרוֹמָיו הוּא יַעֲשֶׂה שָׁלוֹם עָלֵֽינוּ וְעַל כָּל־יִשְׂרָאֵל וְאִמְרוּ אָמֵן:",
                                english: "My God, guard my tongue from evil and my lips from speaking deceitfully. May my soul be unresponsive to those who curse me; and let my soul be like dust to all. Open my heart to Your Torah and let my soul pursue Your commandments. And all who plan evil against me, quickly annul their counsel and frustrate their intention. Act for the sake of Your right hand. Act for the sake of Your holiness. Act for the sake of Your Torah. In order that Your loved ones be released, deliver [with] Your right hand and answer me. May the words of my mouth and the thoughts of my heart be acceptable before You Adonoy, my Rock and my Redeemer. He Who makes peace in His high heavens may He make peace upon us and upon all Israel and say Amein.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "עָלֵֽינוּ לְשַׁבֵּֽחַ לַאֲדוֹן הַכֹּל לָתֵת גְּדֻלָּה לְיוֹצֵר בְּרֵאשִׁית שֶׁלֺּא עָשָֽׂנוּ כְּגוֹיֵי הָאֲרָצוֹת וְלֺא שָׂמָֽנוּ כְּמִשְׁפְּחוֹת הָאֲדָמָה שֶׁלֺּא שָׂם חֶלְקֵֽנוּ כָּהֶם וְגוֹרָלֵֽנוּ כְּכָל הֲמוֹנָם: שֶׁהֵם מִשְׁתַּחֲוִים לָהֶֽבֶל וָרִיק וּמִתְפַּלְּ֒לִים אֶל אֵל לֹא יוֹשִֽׁיעַ, וַאֲנַֽחְנוּ כּוֹרְ֒עִים וּמִשְׁתַּחֲוִים וּמוֹדִים לִפְנֵי מֶֽלֶךְ מַלְכֵי הַמְּ֒לָכִים הַקָּדוֹשׁ בָּרוּךְ הוּא, שֶׁהוּא נוֹטֶה שָׁמַֽיִם וְיוֹסֵד אָֽרֶץ, וּמוֹשַׁב יְקָרוֹ בַּשָּׁמַֽיִם מִמַּֽעַל, וּשְׁ֒כִינַת עֻזּוֹ בְּגָבְ֒הֵי מְרוֹמִים, הוּא אֱלֺהֵֽינוּ אֵין עוֹד, אֱמֶת מַלְכֵּֽנוּ אֶֽפֶס זוּלָתוֹ כַּכָּתוּב בְּתוֹרָתוֹ וְיָדַעְתָּ הַיּוֹם וַהֲשֵׁבֹתָ אֶל לְבָבֶֽךָ כִּי יְהֹוָה הוּא הָאֱלֺהִים בַּשָּׁמַֽיִם מִמַּֽעַל וְעַל הָאָֽרֶץ מִתָּֽחַת אֵין עוֹד:",
                                english: "It is our obligation to praise the Master of all, to ascribe greatness to the Creator of the [world in the] beginning: that He has not made us like the nations of the lands, and has not positioned us like the families of the earth; that He has not assigned our portion like theirs, nor our lot like that of all their multitudes. For they prostrate themselves to vanity and nothingness, and pray to a god that cannot deliver. But we bow, prostrate ourselves, and offer thanks before the Supreme King of Kings, the Holy One blessed is He, Who spreads the heavens, and establishes the earth, and the seat of His glory is in heaven above, and the abode of His invincible might is in the loftiest heights. He is our God, there is nothing else. Our King is true, all else is insignificant, as it is written in His Torah: And You shall know this day and take into Your heart that Adonoy is God in the heavens above and upon the earth below; there is nothing else.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "עַל כֵּן נְקַוֶּה לְךָ יְהֹוָה אֱלֺהֵֽינוּ לִרְאוֹת מְהֵרָה בְּתִפְאֶֽרֶת עֻזֶּֽךָ לְהַעֲבִיר גִּלּוּלִים מִן הָאָֽרֶץ וְהָאֱלִילִים כָּרוֹת יִכָּרֵתוּן לְתַקֵּן עוֹלָם בְּמַלְכוּת שַׁדַּי וְכָל בְּנֵי בָשָׂר יִקְרְאוּ בִשְׁ֒מֶֽךָ, לְהַפְנוֹת אֵלֶֽיךָ כָּל רִשְׁ֒עֵי אָֽרֶץ, יַכִּֽירוּ וְיֵדְ֒עוּ כָּל יוֹשְׁ֒בֵי תֵבֵל כִּי לְךָ תִכְרַע כָּל בֶּֽרֶךְ תִּשָּׁבַע כָּל לָשׁוֹן: לְפָנֶֽיךָ יְהֹוָה אֱלֺהֵֽינוּ יִכְרְעוּ וְיִפֹּֽלוּ, וְלִכְ֒בוֹד שִׁמְךָ יְקָר יִתֵּֽנוּ, וִיקַבְּ֒לוּ כֻלָּם אֶת עֹל מַלְכוּתֶֽךָ, וְתִמְלֺךְ עֲלֵיהֶם מְהֵרָה לְעוֹלָם וָעֶד, כִּי הַמַּלְכוּת שֶׁלְּ֒ךָ הִיא וּלְעֽוֹלְ֒מֵי עַד תִּמְלוֹךְ בְּכָבוֹד, כַּכָּתוּב בְּתוֹרָתֶֽךָ יְהֹוָה יִמְלֺךְ לְעֹלָם וָעֶד: וְנֶאֱמַר וְהָיָה יְהֹוָה לְמֶֽלֶךְ עַל כָּל הָאָֽרֶץ בַּיּוֹם הַהוּא יִהְיֶה יְהֹוָה אֶחָד וּשְׁמוֹ אֶחָד:",
                                english: "We therefore put our hope in You, Adonoy our God, to soon behold the glory of Your might in banishing idolatry from the earth, and the false gods will be utterly exterminated to perfect the world as the kingdom of Shadai. And all mankind will invoke Your Name, to turn back to You, all the wicked of the earth. They will realize and know, all the inhabitants of the world, that to You, every knee must bend, every tongue must swear [allegiance to You]. Before You, Adonoy, our God, they will bow and prostrate themselves, and to the glory of Your Name give honor. And they will all accept [upon themselves] the yoke of Your kingdom, and You will reign over them, soon, forever and ever. For the kingdom is Yours, and to all eternity You will reign in glory, as it is written in Your Torah: Adonoy will reign forever and ever. And it is said: And Adonoy will be King over the whole earth; on that day Adonoy will be One and His Name One.",
                                showEnglish: showEnglish
                            )
                        }
                        .environment(\.siddurFontScale, CGFloat(textScale))
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.2) : .white)
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 15, x: 0, y: 4)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }

                EastCompassBadge()
                    .padding(.trailing, 18)
                    .padding(.bottom, 22)
            }
            .navigationTitle("Mincha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

// MARK: - Maariv View
struct MaarivView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showEnglish: Bool = false
    @AppStorage("siddurTextScale") private var textScale: Double = 1.0

    private var backgroundColor: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ?
                [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.1, green: 0.1, blue: 0.15)] :
                [Color(red: 0.98, green: 0.98, blue: 1.0), Color(red: 0.94, green: 0.96, blue: 1.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                backgroundColor.ignoresSafeArea()

                ScrollView(showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 8) {
                            Text("מעריב")
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundStyle(.primary)

                            Text("Maariv")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 20)

                        // Language Toggle
                        HStack(spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showEnglish = false
                                }
                            } label: {
                                Text("עברית")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(!showEnglish ? .white : .primary)
                                    .frame(width: 80, height: 36)
                                    .background(
                                        Capsule()
                                            .fill(!showEnglish ? Color.blue : Color.clear)
                                    )
                            }

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showEnglish = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("עב")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("+")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("En")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(showEnglish ? .white : .primary)
                                .frame(width: 80, height: 36)
                                .background(
                                    Capsule()
                                        .fill(showEnglish ? Color.blue : Color.clear)
                                )
                            }
                        }
                        .padding(4)
                        .background(
                            Capsule()
                                .fill(colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.25) : Color(red: 0.92, green: 0.92, blue: 0.95))
                        )
                        .padding(.bottom, 10)

                        TextSizeControl(textScale: $textScale)
                            .padding(.bottom, 20)

                        // Prayer Content
                        VStack(alignment: .leading, spacing: 0) {
                            PrayerBlock(
                                hebrew: "בָּרְ֒כוּ אֶת יְהֹוָה הַמְ֒בֹרָךְ:",
                                english: "Bless Adonoy Who is blessed.",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "ועונין הקהל:",
                                english: "The congregation responds and the Chazzan repeats:",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "בָּרוּךְ יְהֹוָה הַמְ֒בֹרָךְ לְעוֹלָם וָעֶד:",
                                english: "Blessed is Adonoy, Who is blessed forever and ever.",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "בָּרוּךְ אַתָּה יְהֹוָה אֱלֹהֵֽינוּ מֶֽלֶךְ הָעוֹלָם אֲשֶׁר בִּדְבָרוֹ מַעֲרִיב עֲרָבִים בְּחָכְמָה פּוֹתֵֽחַ שְׁעָרִים וּבִתְבוּנָה מְשַׁנֶּה עִתִּים וּמַחֲלִיף אֶת־הַזְּ֒מַנִּים וּמְסַדֵּר אֶת־הַכּוֹכָבִים בְּמִשְׁמְ֒רוֹתֵיהֶם בָּרָקִֽיעַ כִּרְצוֹנוֹ: בּוֹרֵא יוֹם וָלָֽיְלָה גּוֹלֵל אוֹר מִפְּ֒נֵי חֽשֶׁךְ וְחֽשֶׁךְ מִפְּ֒נֵי אוֹר וּמַעֲבִיר יוֹם וּמֵבִיא לָֽיְלָה וּמַבְדִּיל בֵּין יוֹם וּבֵין לָֽיְלָה יְהֹוָה צְבָאוֹת שְׁמוֹ: אֵל חַי וְקַיָּם תָּמִיד יִמְלֹךְ עָלֵֽינוּ לְעוֹלָם וָעֶד: בָּרוּךְ אַתָּה יְהֹוָה הַמַּעֲרִיב עֲרָבִים:",
                                english: "Blessed are You, Adonoy, our God, King of the Universe, With His word He brings on evenings, with wisdom He opens the gates (of heaven); and with understanding changes the times and alternates the seasons, and arranges the stars in their watches, in the sky, according to His will. He creates day and night, He rolls the light away from before darkness, and darkness from before light; He causes day to pass and brings night, and separates between day and night; Adonoy of Hosts is His Name. The Almighty, Who is living and enduring will always reign over us forever and ever. Blessed are You, Adonoy, Who brings on evening.",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "אַהֲבַת עוֹלָם בֵּית יִשְׂרָאֵל עַמְּ֒ךָ אָהָֽבְתָּ תּוֹרָה וּמִצְוֹת חֻקִּים וּמִשְׁפָּטִים אוֹתָֽנוּ לִמַּֽדְתָּ: עַל כֵּן יְהֹוָה אֱלֹהֵֽינוּ בְּשָׁכְבֵֽנוּ וּבְקוּמֵֽנוּ נָשִֽׂיחַ בְּחֻקֶּֽיךָ וְנִשְׂמַח בְּדִבְרֵי תוֹרָתֶֽךָ וּבְמִצְוֹתֶֽיךָ לְעוֹלָם וָעֶד: כִּי הֵם חַיֵּֽינוּ וְאֹֽרֶךְ יָמֵֽינוּ וּבָהֶם נֶהְגֶּה יוֹמָם וָלָֽיְלָה: וְאַהֲבָתְ֒ךָ אַל תָּסִיר מִמֶּֽנּוּ לְעוֹלָמִים: בָּרוּךְ אַתָּה יְהֹוָה אוֹהֵב עַמּוֹ יִשְׂרָאֵל:",
                                english: "An everlasting love You loved the House of Israel, Your people. You taught us Torah and commandments, statutes and laws. Therefore, Adonoy, our God, when we lie down and when we rise, we will discuss Your statutes, and rejoice in the words of Your Torah and in Your commandments forever. For they are our life and they lengthen our days, and on them we will meditate day and night. May Your love never be removed from us. Blessed are You, Adonoy, Who loves His people Israel.",
                                showEnglish: showEnglish
                            )


                            PrayerBlock(
                                hebrew: "שְׁמַע יִשְׂרָאֵל יְהֹוָה אֱלֹהֵֽינוּ יְהֹוָה אֶחָד:",
                                english: "Hear, Israel: Adonoy is our God, Adonoy is One.",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "בָּרוּךְ שֵׁם כְּבוֹד מַלְכוּתוֹ לְעוֹלָם וָעֶד:",
                                english: "Blessed is His Name, Whose glorious kingdom is forever and ever.",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "וְאָהַבְתָּ אֵת יְהֹוָה אֱלֹהֶֽיךָ בְּכָל֯־לְ֯בָבְ֒ךָ וּבְכָל־נַפְשְׁ֒ךָ וּבְכָל־מְאֹדֶֽךָ: וְהָיוּ הַדְּ֒בָרִים הָאֵֽלֶּה אֲשֶׁר֯ אָ֯נֹכִי מְצַוְּ֒ךָ הַיּוֹם עַל֯־לְ֯בָבֶֽךָ: וְשִׁנַּנְתָּם לְבָנֶֽיךָ וְדִבַּרְתָּ בָּם בְּשִׁבְתְּ֒ךָ בְּבֵיתֶֽךָ וּבְלֶכְתְּ֒ךָ בַדֶּֽרֶךְ וְשָׁכְבְּ֒ךָ וּבְקוּמֶֽךָ: וּקְשַׁרְתָּם לְאוֹת עַל֯־יָ֯דֶֽךָ וְהָיוּ לְטֹטָפֹת בֵּין עֵינֶֽיךָ: וּכְתַבְתָּם עַל־מְזֻזוֹת בֵּיתֶֽךָ וּבִשְׁעָרֶֽיךָ:",
                                english: "And you shall love Adonoy your God with all your heart and with all your soul and with all your possessions. And these words which I command you today, shall be upon your heart. And you shall teach them sharply to your children. And you shall discuss them when you sit in your house, and when you travel on the road, and when you lie down and when you rise. And you shall bind them for a sign upon your hand, and they shall be for totafos between your eyes. And you shall write them upon the doorposts of your house and upon your gateways.",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "וְהָיָה אִם־שָׁמֹֽעַ תִּשְׁמְעוּ אֶל־מִצְוֹתַי אֲשֶׁר֯ אָ֯נֹכִי מְצַוֶּה אֶתְ֒כֶם הַיּוֹם לְאַהֲבָה אֶת־יְהֹוָה אֱלֹהֵיכֶם וּלְעָבְ֒דוֹ בְּכָל־לְבַבְכֶם וּבְכָל־נַפְשְׁכֶם: וְנָתַתִּי מְטַר֯־אַ֯רְצְכֶם בְּעִתּוֹ יוֹרֶה וּמַלְקוֹשׁ וְאָסַפְתָּ דְגָנֶֽךָ וְתִירשְׁךָ וְיִצְהָרֶֽךָ: וְנָתַתִּי עֵֽשֶׂב֯ בְּ֯שָׂדְ֒ךָ לִבְ֒הֶמְתֶּֽךָ וְאָכַלְתָּ וְשָׂבָֽעְתָּ: הִשָּׁמְ֒רוּ לָכֶם פֶּן֯־יִ֯פְתֶּה לְבַבְכֶם וְסַרְתֶּם וַעֲבַדְתֶּם אֱלֹהִים֯ אֲ֯חֵרִים וְהִשְׁתַּחֲוִיתֶם לָהֶם: וְחָרָה אַף־יְהֹוָה בָּכֶם וְעָצַר֯ אֶ֯ת־הַשָּׁמַֽיִם וְלֹא֯־יִ֯הְיֶה מָטָר וְהָאֲדָמָה לֹא תִתֵּן אֶת֯־יְ֯בוּלָהּ וַאֲבַדְתֶּם֯ מְ֯הֵרָה מֵעַל הָאָֽרֶץ הַטֹּבָה אֲשֶׁר֯ יְ֯הֹוָה נֹתֵן לָכֶם: וְשַׂמְתֶּם֯ אֶ֯ת־דְּבָרַי֯ אֵֽ֯לֶּה עַל֯־לְ֯בַבְכֶם וְעַל־נַפְשְׁכֶם וּקְשַׁרְתֶּם֯ אֹ֯תָם לְאוֹת עַל֯־יֶ֯דְ֒כֶם וְהָיוּ לְטוֹטָפֹת בֵּין עֵינֵיכֶם: וְלִמַּדְתֶּם֯ אֹ֯תָם אֶת־בְּנֵיכֶם לְדַבֵּר בָּם בְּשִׁבְתְּךָ בְּבֵיתֶֽךָ וּבְלֶכְתְּ֒ךָ בַדֶּֽרֶךְ וְשָׁכְבְּ֒ךָ וּבְקוּמֶֽךָ: וּכְתַבְתָּם עַל־מְזוּזוֹת בֵּיתֶֽךָ וּבִשְׁ֒עָרֶֽיךָ: לְמַֽעַן֯ יִ֯רְבּוּ יְמֵיכֶם וִימֵי בְנֵיכֶם עַל הָאֲדָמָה אֲשֶׁר נִשְׁבַּע יְהֹוָה לַאֲבֹתֵיכֶם לָתֵת לָהֶם כִּימֵי הַשָּׁמַֽיִם עַל־הָאָֽרֶץ:",
                                english: "And it will be— if you vigilantly obey My commandments which I command you this day, to love Adonoy your God, and serve Him with your entire hearts and with your entire souls— that I will give rain for your land in its proper time, the early (autumn) rain and the late (spring) rain; and you will harvest your grain and your wine and your oil. And I will put grass in your fields for your cattle, and you will eat and be satisfied. Beware lest your hearts be swayed and you turn astray, and you worship alien gods and bow to them. And Adonoy’s fury will blaze among you, and He will close off the heavens and there will be no rain and the earth will not yield its produce; and you will perish swiftly from the good land which Adonoy gives you. Place these words of Mine upon your hearts and upon your souls, and bind them for a sign upon your hands, and they shall be for totafos between your eyes. And you shall teach them to your sons, to speak them when you sit in your house, and when you travel on the road, and when you lie down and when you rise. And you shall write them upon the doorposts of your house and upon your gateways. In order that your days be prolonged, and the days of your children, upon the land which Adonoy swore to your fathers to give them for as long as the heavens are above the earth.",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "וַֽיֹּאמֶר֯ יְהֹוָה֯ אֶ֯ל־משֶׁה לֵּאמֹר: דַּבֵּר֯ אֶ֯ל־בְּנֵי יִשְׂרָאֵל וְאָמַרְתָּ אֲלֵהֶם וְעָשׂוּ לָהֶם צִיצִת עַל־כַּנְפֵי בִגְ֒דֵיהֶם לְדֹרֹתָם וְנָתְ֒נוּ עַל־צִיצִת הַכָּנָף֯ פְּ֯תִיל תְּכֵֽלֶת: וְהָיָה לָכֶם לְצִיצִת וּרְאִיתֶם֯ אֹ֯תוֹ וּזְכַרְתֶּם֯ אֶ֯ת־כָּל־מִצְוֹת֯ יְ֯הֹוָה וַעֲשִׂיתֶם֯ אֹ֯תָם וְלֹא תָתֽוּרוּ אַחֲרֵי לְבַבְכֶם וְאַחֲרֵי עֵינֵיכֶם אֲשֶׁר֯־אַ֯תֶּם זֹנִים֯ אַ֯חֲרֵיהֶם: לְמַֽעַן תִּזְכְּרוּ וַעֲשִׂיתֶם֯ אֶ֯ת־כָּל־מִצְוֹתָי וִהְיִיתֶם קְדשִׁים לֵאלֹהֵיכֶם: אֲנִי יְהֹוָה אֱלֹהֵיכֶם֯ אֲ֯שֶׁר הוֹצֵֽאתִי אֶתְ֒כֶם֯ מֵ֯אֶֽרֶץ מִצְרַֽיִם לִהְיוֹת לָכֶם לֵאלֹהִים֯ אֲ֯נִי יְהֹוָה אֱלֹהֵיכֶם֯:",
                                english: "And Adonoy spoke to Moses saying: Speak to the children of Israel, and tell them to make for themselves fringes on the corners of their garments throughout their generations; and they will place with the fringes of each corner a thread of blue. And it will be to you for fringes, and you will look upon it and you will remember all the commandments of Adonoy and you will perform them; and you will not turn aside after your hearts and after your eyes which cause you to go astray. In order that you will remember and perform all My commandments; and you will be holy unto your God. I am Adonoy, your God, Who brought you out of the land of Egypt to be your God: I am Adonoy, your God.",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "אֱ֯מֶת",
                                english: "is true",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "וֶאֱמוּנָה כָּל־זֹאת וְקַיָּם עָלֵֽינוּ כִּי הוּא יְהֹוָה אֱלֹהֵֽינוּ וְאֵין זוּלָתוֹ וַאֲנַֽחְנוּ יִשְׂרָאֵל עַמּוֹ: הַפּוֹדֵֽנוּ מִיַּד מְלָכִים מַלְכֵּֽנוּ הַגּוֹאֲלֵֽנוּ מִכַּף כָּל־הֶעָרִיצִים: הָאֵל הַנִּפְרָע לָֽנוּ מִצָּרֵֽינוּ וְהַמְשַׁלֵּם גְּמוּל לְכָל אֹיְ֒בֵי נַפְשֵֽׁנוּ: הָעֹשֶׂה גְדוֹלוֹת עַד־אֵין חֵֽקֶר וְנִפְלָאוֹת עַד־אֵין מִסְפָּר: הַשָּׂם נַפְשֵֽׁנוּ בַּחַיִּים וְלֹא־נָתַן לַמּוֹט רַגְלֵֽנוּ הַמַּדְרִיכֵֽנוּ עַל בָּמוֹת אֹיְ֒בֵֽינוּ וַיָּֽרֶם קַרְנֵֽנוּ עַל כָּל־שׂוֹנְ֒אֵֽינוּ: הָעֹֽשֶׂה לָּֽנוּ נִסִּים וּנְקָמָה בְּפַרְעֹה אוֹתוֹת וּמוֹפְ֒תִים בְּאַדְמַת בְּנֵי חָם: הַמַּכֶּה בְעֶבְרָתוֹ כָּל בְּכוֹרֵי מִצְרָֽיִם וַיּוֹצֵא אֶת־עַמּוֹ יִשְׂרָאֵל מִתּוֹכָם לְחֵרוּת עוֹלָם: הַמַּעֲבִיר בָּנָיו בֵּין גִּזְרֵי יַם סוּף אֶת־רוֹדְ֒פֵיהֶם וְאֶת־שׂוֹנְ֒אֵיהֶם בִּתְהוֹמוֹת טִבַּע: וְרָאוּ בָנָיו גְּבוּרָתוֹ שִׁבְּ֒חוּ וְהוֹדוּ לִשְׁמוֹ: וּמַלְכוּתוֹ בְרָצוֹן קִבְּ֒לוּ עֲלֵיהֶם משֶׁה וּבְנֵי יִשְׂרָאֵל לְךָ עָנוּ שִׁירָה בְּשִׂמְחָה רַבָּה וְאָמְ֒רוּ כֻלָּם:",
                                english: "And faithful is all this, and it is permanently established with us that He is Adonoy, our God, and there is nothing besides Him, and that we, Israel, are His people. He Who liberated us from the hand of kings is our King, Who redeemed us from the grasp of all the tyrants. He is the Almighty Who exacts payment from our oppressors, and brings retribution on all those who are enemies of our soul. He does great things beyond comprehension, miracles and wonders without number. He sustains our soul in life and does not allow our feet to slip. He makes us tread upon the high places of our enemies, and exalts our strength over all who hate us. He performed miracles for us and vengeance upon Pharaoh, signs and wonders in the land of the Hamites. He slew in His wrath all the firstborn of Egypt, and brought out His people, Israel, from their midst to everlasting freedom. He led His children through the divided parts of the Sea of Reeds, their pursuers and their enemies He drowned in its depths. And His children saw His mighty power. They praised and gave thanks to His Name, His sovereignty they willingly accepted. Moses and the children of Israel sang unto You with great joy, and they all said:",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "מִי כָמֹֽכָה בָּאֵלִם יְהֹוָה מִי כָּמֹֽכָה נֶאְדָּר בַּקֹּֽדֶשׁ נוֹרָא תְהִלֹּת עֹֽשֵׂה פֶֽלֶא: מַלְכוּתְךָ רָאוּ בָנֶֽיךָ בּוֹקֵֽעַ יָם לִפְנֵי משֶׁה זֶה אֵלִי עָנוּ וְאָמְ֒רוּ:",
                                english: "Who is like You among the mighty, Adonoy. Who is like You, adorned in holiness, awesome in praise, performing wonders. Your children beheld Your sovereignty when You divided the sea before Moses. This is my God, they exclaimed, and declared,",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "יְהֹוָה יִמְלֹךְ לְעֹלָם וָעֶד: וְנֶאֱמַר כִּי־פָדָה יְהֹוָה אֶת יַעֲקֹב וּגְאָלוֹ מִיַּד חָזָק מִמֶּֽנּוּ. בָּרוּךְ אַתָּה יְהֹוָה גָּאַל יִשְׂרָאֵל:",
                                english: "Adonoy will reign forever and ever. And it is said, For Adonoy has liberated Jacob and redeemed him from a hand, mightier than his. Blessed are You, Adonoy Who has redeemed Israel.",
                                showEnglish: showEnglish
                            )


                            PrayerBlock(
                                hebrew: "הַשְׁכִּיבֵֽנוּ יְהֹוָה אֱלֹהֵֽינוּ לְשָׁלוֹם וְהַעֲמִידֵֽנוּ מַלְכֵּֽנוּ לְחַיִּים וּפְרוֹשׂ עָלֵֽינוּ סֻכַּת שְׁלוֹמֶֽךָ וְתַקְּ֒נֵֽנוּ בְּעֵצָה טוֹבָה מִלְּ֒פָנֶֽיךָ וְהוֹשִׁיעֵֽנוּ לְמַֽעַן שְׁמֶֽךָ וְהָגֵן בַּעֲדֵֽנוּ וְהָסֵר מֵעָלֵֽינוּ אוֹיֵב דֶּֽבֶר וְחֶֽרֶב וְרָעָב וְיָגוֹן וְהָסֵר שָׂטָן מִלְּפָנֵֽינוּ וּמֵאַחֲרֵֽינוּ וּבְצֵל כְּנָפֶֽיךָ תַּסְתִּירֵֽנוּ כִּי אֵל שׁוֹמְ֒רֵֽנוּ וּמַצִּילֵֽנוּ אָֽתָּה כִּי אֵל מֶֽלֶךְ חַנּוּן וְרַחוּם אָֽתָּה וּשְׁמוֹר צֵאתֵֽנוּ וּבוֹאֵֽנוּ לְחַיִּים וּלְשָׁלוֹם מֵעַתָּה וְעַד עוֹלָם: בָּרוּךְ אַתָּה יְהֹוָה שׁוֹמֵר עַמּוֹ יִשְׂרָאֵל לָעַד:",
                                english: "Adonoy our God, make us lie down in peace, our King, raise us again to life. Spread over us the shelter of Your peace, and direct us to better ourselves through Your good counsel, and deliver us for Your Name’s sake. Shield us, and remove from us enemies, pestilence, sword, famine and sorrow. Remove the adversary from before us and from behind us, and shelter us in the shadow of Your wings. For Almighty, You are our Protector and Rescuer. For Almighty You are a gracious and merciful King. Guard our going out and our coming in for life and peace for now forever. Blessed are You, Adonoy, Who guards His people Israel forever.",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "אֲדֹנָי שְׂפָתַי תִּפְתָּח וּפִי יַגִּיד תְּהִלָּתֶֽךָ:",
                                english: "My Master, open my lips, and my mouth will declare Your praise.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "בָּרוּךְ אַתָּה יְהֹוָה אֱלֹהֵֽינוּ וֵאלֹהֵי אֲבוֹתֵֽינוּ אֱלֹהֵי אַבְרָהָם אֱלֹהֵי יִצְחָק וֵאלֹהֵי יַעֲקֹב הָאֵל הַגָּדוֹל הַגִּבּוֹר וְהַנּוֹרָא אֵל עֶלְיוֹן גּוֹמֵל חֲסָדִים טוֹבִים וְקוֹנֵה הַכֹּל וְזוֹכֵר חַסְדֵי אָבוֹת וּמֵבִיא גוֹאֵל לִבְנֵי בְנֵיהֶם לְמַֽעַן שְׁמוֹ בְּאַהֲבָה:",
                                english: "Blessed are You, Adonoy, our God, and God of our fathers, God of Abraham, God of Isaac, and God of Jacob, the Almighty, the Great, the Powerful, the Awesome, most high Almighty, Who bestows beneficent kindness, Who possesses everything, Who remembers the piety of the Patriarchs, and Who brings a redeemer to their children's children, for the sake of His Name, with love.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "מֶֽלֶךְ עוֹזֵר וּמוֹשִֽׁיעַ וּמָגֵן: בָּרוּךְ אַתָּה יְהֹוָה מָגֵן אַבְרָהָם:",
                                english: "King, Helper, and Deliverer and Shield. Blessed are You, Adonoy, Shield of Abraham.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "אַתָּה גִבּוֹר לְעוֹלָם אֲדֹנָי מְחַיֶּה מֵתִים אַתָּה רַב לְהוֹשִֽׁיעַ:",
                                english: "You are mighty forever, my Master; You are the Resurrector of the dead the Powerful One to deliver us.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "מַשִּׁיב הָרֽוּחַ וּמוֹרִיד הַגֶּֽשֶׁם: מְכַלְכֵּל חַיִּים בְּחֶֽסֶד מְחַיֵּה מֵתִים בְּרַחֲמִים רַבִּים סוֹמֵךְ נוֹפְ֒לִים וְרוֹפֵא חוֹלִים וּמַתִּיר אֲסוּרִים וּמְקַיֵּם אֱמוּנָתוֹ לִישֵׁנֵי עָפָר, מִי כָמֽוֹךָ בַּֽעַל גְּבוּרוֹת וּמִי דּֽוֹמֶה לָּךְ מֶֽלֶךְ מֵמִית וּמְחַיֶּה וּמַצְמִֽיחַ יְשׁוּעָה:",
                                english: "Causer of the wind to blow and of the rain to fall. Sustainer of the living with kindliness, Resurrector of the dead with great mercy, Supporter of the fallen, and Healer of the sick, and Releaser of the imprisoned, and Fulfiller of His faithfulness to those who sleep in the dust. Who is like You, Master of mighty deeds, and who can be compared to You? King Who causes death and restores life, and causes deliverance to sprout forth.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "וְנֶאֱמָן אַתָּה לְהַחֲיוֹת מֵתִים: בָּרוּךְ אַתָּה יְהֹוָה מְחַיֵּה הַמֵּתִים:",
                                english: "And You are faithful to restore the dead to life. Blessed are You, Adonoy, Resurrector of the dead.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "אַתָּה קָדוֹשׁ וְשִׁמְךָ קָדוֹשׁ וּקְדוֹשִׁים בְּכָל־יוֹם יְהַלְ֒לֽוּךָ סֶּֽלָה. בָּרוּךְ אַתָּה יְהֹוָה הָאֵל הַקָּדוֹשׁ:",
                                english: "You are holy and Your Name is holy and holy beings praise You every day, forever. Blessed are You, Adonoy, the Almighty, the Holy One.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "אַתָּה חוֹנֵן לְאָדָם דַּֽעַת וּמְלַמֵּד לֶאֱנוֹשׁ בִּינָה: חָנֵּֽנוּ מֵאִתְּ֒ךָ דֵּעָה בִּינָה וְהַשְׂכֵּל: בָּרוּךְ אַתָּה יְהֹוָה חוֹנֵן הַדָּֽעַת:",
                                english: "You favor man with perception and teach mankind understanding. Grant us knowledge, understanding and intellect from You. Blessed are You, Adonoy, Grantor of perception.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "הֲשִׁיבֵֽנוּ אָבִֽינוּ לְתוֹרָתֶֽךָ וְקָרְ֒בֵֽנוּ מַלְכֵּֽנוּ לַעֲבוֹדָתֶֽךָ וְהַחֲזִירֵֽנוּ בִּתְשׁוּבָה שְׁלֵמָה לְפָנֶֽיךָ: בָּרוּךְ אַתָּה יְהֹוָה הָרוֹצֶה בִּתְשׁוּבָה:",
                                english: "Cause us to return, our Father, to Your Torah and bring us near, our King, to Your service; and bring us back in whole-hearted repentance before You Blessed are You, Adonoy, Who desires penitence.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "סְלַח לָֽנוּ אָבִֽינוּ כִּי חָטָֽאנוּ מְחַל לָֽנוּ מַלְכֵּֽנוּ כִּי פָשָֽׁעְנוּ כִּי מוֹחֵל וְסוֹלֵֽחַ אָֽתָּה: בָּרוּךְ אַתָּה יְהֹוָה חַנּוּן הַמַּרְבֶּה לִסְלֽוֹחַ:",
                                english: "Pardon us, our Father, for we have sinned, forgive us, our King, for we have transgressed; for You forgive and pardon. Blessed are You, Adonoy, Gracious One, Who pardons abundantly.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "רְאֵה בְעָנְיֵֽנוּ וְרִיבָה רִיבֵֽנוּ וּגְאָלֵֽנוּ מְהֵרָה לְמַֽעַן שְׁמֶֽךָ כִּי גּוֹאֵל חָזָק אָֽתָּה: בָּרוּךְ אַתָּה יְהֹוָה גּוֹאֵל יִשְׂרָאֵל:",
                                english: "Look upon our affliction, and defend our cause: and redeem us speedily for the sake of Your Name; because You are a Mighty Redeemer. Blessed are You, Adonoy, Redeemer of Israel.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "רְפָאֵֽנוּ יְהֹוָה וְנֵרָפֵא הוֹשִׁיעֵֽנוּ וְנִוָּשֵֽׁעָה כִּי תְהִלָּתֵֽנוּ אָֽתָּה וְהַעֲלֵה רְפוּאָה שְׁלֵמָה לְכָל מַכּוֹתֵֽינוּ כִּי אֵל מֶֽלֶךְ רוֹפֵא נֶאֱמָן וְרַחֲמָן אָֽתָּה: בָּרוּךְ אַתָּה יְהֹוָה רוֹפֵא חוֹלֵי עַמּוֹ יִשְׂרָאֵל:",
                                english: "Heal us, Adonoy, and we will be healed, deliver us and we will be delivered; for You are our praise. Grant a complete healing to all our affliction because You are the Almighty, King, Who is a faithful and merciful Healer. Blessed are You, Adonoy, Healer of the sick of His people Israel.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "בָּרֵךְ עָלֵֽינוּ יְהֹוָה אֱלֹהֵֽינוּ אֶת־הַשָּׁנָה הַזֹּאת וְאֶת־כָּל־מִינֵי תְבוּאָתָהּ לְטוֹבָה, וְתֵן בְּרָכָה / טַל וּמָטָר לִבְרָכָה עַל פְּנֵי הָאֲדָמָה וְשַׂבְּ֒עֵֽנוּ מִטּוּבֶֽךָ וּבָרֵךְ שְׁנָתֵֽנוּ כַּשָּׁנִים הַטּוֹבוֹת: בָּרוּךְ אַתָּה יְהֹוָה מְבָרֵךְ הַשָּׁנִים:",
                                english: "Bless for us, Adonoy our God, this year and all the varieties of its produce for good; and bestow blessing / dew and rain for a blessing upon the face of the earth; satisfy us from Your bounty and bless our year, like the good years. Blessed are You, Adonoy, Blesser of the years.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "תְּקַע בְּשׁוֹפָר גָּדוֹל לְחֵרוּתֵֽנוּ וְשָׂא נֵס לְקַבֵּץ גָּלֻיּוֹתֵֽינוּ וְקַבְּ֒צֵֽנוּ יַֽחַד מֵאַרְבַּע כַּנְפוֹת הָאָֽרֶץ: בָּרוּךְ אַתָּה יְהֹוָה מְקַבֵּץ נִדְחֵי עַמּוֹ יִשְׂרָאֵל:",
                                english: "Sound the great shofar for our liberty, and raise a banner to gather our exiles, and gather us together from the four corners of the earth. Blessed are You, Adonoy, Gatherer of the dispersed of His people Israel.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "הָשִֽׁיבָה שׁוֹפְ֒טֵֽינוּ כְּבָרִאשׁוֹנָה וְיוֹעֲצֵֽינוּ כְּבַתְּ֒חִלָּה וְהָסֵר מִמֶּֽנּוּ יָגוֹן וַאֲנָחָה וּמְלוֹךְ עָלֵֽינוּ אַתָּה יְהֹוָה לְבַדְּ֒ךָ בְּחֶֽסֶד וּבְרַחֲמִים וְצַדְּ֒קֵֽנוּ בַּמִשְׁפָּט: בָּרוּךְ אַתָּה יְהֹוָה מֶֽלֶךְ אֹהֵב צְדָקָה וּמִשְׁפָּט:",
                                english: "Restore our judges as before and our counselors as at first. Remove sorrow and sighing from us, and reign over us You, Adonoy, alone with kindness and compassion; and make us righteous with justice, Blessed are You, Adonoy, King, Lover of righteousness and justice.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "וְלַמַּלְשִׁינִים אַל תְּהִי תִקְוָה וְכָל הָרִשְׁעָה כְּרֶֽגַע תֹּאבֵד וְכָל אֹיְבֶֽיךָ מְהֵרָה יִכָּרֵֽתוּ וְהַזֵּדִים מְהֵרָה תְעַקֵּר וּתְשַׁבֵּר וּתְמַגֵּר וְתַכְנִֽיעַ בִּמְהֵרָה בְיָמֵֽינוּ: בָּרוּךְ אַתָּה יְהֹוָה שׁוֹבֵר אֹיְ֒בִים וּמַכְנִֽיעַ זֵדִים:",
                                english: "Let there be no hope for informers and may all wickedness instantly perish; may all the enemies of Your people be swiftly cut off, and may You quickly uproot, crush, rout and subdue the insolent, speedily in our days. Blessed are You, Adonoy, Crusher of enemies and Subduer of the insolent.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "עַל־הַצַּדִּיקִים וְעַל־הַחֲסִידִים וְעַל־זִקְנֵי עַמְּ֒ךָ בֵּית יִשְׂרָאֵל וְעַל פְּלֵיטַת סוֹפְ֒רֵיהֶם וְעַל גֵּרֵי הַצֶּֽדֶק וְעָלֵֽינוּ יֶהֱמוּ רַחֲמֶֽיךָ יְהֹוָה אֱלֹהֵֽינוּ וְתֵן שָׂכָר טוֹב לְכָל הַבּוֹטְ֒חִים בְּשִׁמְךָ בֶּאֱמֶת וְשִׂים חֶלְקֵֽנוּ עִמָּהֶם לְעוֹלָם וְלֹא נֵבוֹשׁ כִּי בְךָ בָּטָֽחְנוּ: בָּרוּךְ אַתָּה יְהֹוָה מִשְׁעָן וּמִבְטָח לַצַּדִּיקִים:",
                                english: "May Your mercy be aroused, Adonoy our God, upon the righteous, upon the pious, upon the elders of Your people, Israel, upon the remnant of their scholars, upon the true proselytes and upon us. Grant bountiful reward to all who trust in Your Name in truth; and place our lot among them, and may we never be put to shame, for we have put our trust in You. Blessed are You, Adonoy, Support and Trust of the righteous.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "וְלִירוּשָׁלַֽיִם עִירְ֒ךָ בְּרַחֲמִים תָּשׁוּב וְתִשְׁכּוֹן בְּתוֹכָהּ כַּאֲשֶׁר דִּבַּֽרְתָּ וּבְנֵה אוֹתָהּ בְּקָרוֹב בְּיָמֵֽינוּ בִּנְיַן עוֹלָם וְכִסֵּא דָוִד מְהֵרָה לְתוֹכָהּ תָּכִין: בָּרוּךְ אַתָּה יְהֹוָה בּוֹנֵה יְרוּשָׁלָֽיִם:",
                                english: "And return in mercy to Jerusalem, Your city, and dwell therein as You have spoken; and rebuild it soon, in our days, as an everlasting structure, and may You speedily establish the throne of David therein. Blessed are You, Adonoy, Builder of Jerusalem.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "אֶת־צֶֽמַח דָּוִד עַבְדְּ֒ךָ מְהֵרָה תַצְמִֽיחַ וְקַרְנוֹ תָּרוּם בִּישׁוּעָתֶֽךָ כִּי לִישׁוּעָתְ֒ךָ קִוִּֽינוּ כָּל הַיּוֹם: בָּרוּךְ אַתָּה יְהֹוָה מַצְמִֽיחַ קֶֽרֶן יְשׁוּעָה:",
                                english: "Speedily cause the sprout of David, Your servant, to flourish and exalt his power with Your deliverance. We hope all day for Your deliverance. Blessed are You, Adonoy, Who causes the power of salvation to sprout.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "שְׁמַע קוֹלֵֽנוּ יְהֹוָה אֱלֹהֵֽינוּ חוּס וְרַחֵם עָלֵֽינוּ וְקַבֵּל בְּרַחֲמִים וּבְרָצוֹן אֶת־תְּפִלָּתֵֽנוּ כִּי אֵל שׁוֹמֵֽעַ תְּפִלּוֹת וְתַחֲנוּנִים אָֽתָּה וּמִלְּפָנֶֽיךָ מַלְכֵּֽנוּ רֵיקָם אַל־תְּשִׁיבֵֽנוּ כִּי אַתָּה שׁוֹמֵֽעַ תְּפִלַּת עַמְּךָ יִשְׂרָאֵל בְּרַחֲמִים: בָּרוּךְ אַתָּה יְהֹוָה שׁוֹמֵֽעַ תְּפִלָּה:",
                                english: "Hear our voice, Adonoy, our God; spare us and have compassion on us, and accept our prayers compassionately and willingly, for You are Almighty Who hears prayers and supplications; and do not turn us away empty-handed from Your Presence, our King, for You hear the prayers of Your people, Israel, with compassion. Blessed are You, Adonoy, Who hears prayers.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "רְצֵה יְהֹוָה אֱלֹהֵֽינוּ בְּעַמְּ֒ךָ יִשְׂרָאֵל וּבִתְפִלָּתָם וְהָשֵׁב אֶת הָעֲבוֹדָה לִדְבִיר בֵּיתֶֽךָ וְאִשֵּׁי יִשְׂרָאֵל וּתְפִלָּתָם בְּאַהֲבָה תְקַבֵּל בְּרָצוֹן וּתְהִי לְרָצוֹן תָּמִיד עֲבוֹדַת יִשְׂרָאֵל עַמֶּֽךָ: וְתֶחֱזֶֽינָה עֵינֵֽינוּ בְּשׁוּבְ֒ךָ לְצִיּוֹן בְּרַחֲמִים: בָּרוּךְ אַתָּה יְהֹוָה הַמַּחֲזִיר שְׁכִינָתוֹ לְצִיּוֹן:",
                                english: "Be pleased, Adonoy, our God, with Your people, Israel, and their prayer; and restore the service to the Holy of Holies in Your abode, and the fire-offerings of Israel; and accept their prayer, lovingly and willingly. And may You always find pleasure with the service of Your people, Israel. And may our eyes behold Your merciful return to Zion. Blessed are You, Adonoy, Who returns His Divine Presence to Zion.",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "אֱלֹהֵֽינוּ וֵאלֹהֵי אֲבוֹתֵֽינוּ יַעֲלֶה וְיָבֹא וְיַגִּֽיעַ וְיֵרָאֶה וְיֵרָצֶה וְיִשָּׁמַע וְיִפָּקֵד וְיִזָּכֵר זִכְרוֹנֵֽנוּ וּפִקְדוֹנֵֽנוּ וְזִכְרוֹן אֲבוֹתֵֽינוּ וְזִכְרוֹן מָשִֽׁיחַ בֶּן דָּוִד עַבְדֶּֽךָ וְזִכְרוֹן יְרוּשָׁלַֽיִם עִיר קָדְשֶֽׁךָ וְזִכְרוֹן כָּל עַמְּ֒ךָ בֵּית יִשְׂרָאֵל לְפָנֶֽיךָ, לִפְלֵיטָה לְטוֹבָה לְחֵן וּלְחֶֽסֶד וּלְרַחֲמִים וּלְחַיִּים טוֹבִים וּלְשָׁלוֹם בְּיוֹם לר\"ח: רֹאשׁ הַחֹֽדֶשׁ הַזֶּה. לפסח: חַג הַמַּצּוֹת הַזֶּה. לסכות: חַג הַסֻּכּוֹת הַזֶּה. זָכְרֵֽנוּ יְהֹוָה אֱלֹהֵֽינוּ בּוֹ לְטוֹבָה, וּפָקְדֵֽנוּ בוֹ לִבְרָכָה, וְהוֹשִׁיעֵֽנוּ בוֹ לְחַיִּים טוֹבִים, וּבִדְבַר יְשׁוּעָה וְרַחֲמִים חוּס וְחָנֵּֽנוּ, וְרַחֵם עָלֵֽינוּ וְהוֹשִׁיעֵֽנוּ, כִּי אֵלֶֽיךָ עֵינֵֽינוּ, כִּי אֵל מֶֽלֶךְ חַנּוּן וְרַחוּם אָֽתָּה:",
                                english: "Our God and God of our fathers, may there ascend, come, and reach, appear, be desired, and heard, counted and recalled our remembrance and reckoning; the remembrance of our fathers; the remembrance of the Messiah the son of David, Your servant; the remembrance of Jerusalem, city of Your Sanctuary; and the remembrance of Your entire people, the House of Israel, before You for survival, for well-being, for favor, kindliness, compassion, for good life and peace on this day of: Rosh Chodesh: this Rosh Chodesh. Pesach: this Festival of Matzos. Sukkos: this Festival of Sukkos. Remember us, Adonoy our God, on this day for well-being; be mindful of us on this day for blessing; and deliver us for good life. In accord with the promise of deliverance and compassion, spare us and favor us, have compassion on us and deliver us; for our eyes are directed to You, because You are the Almighty Who is King, Gracious, and Merciful.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "מוֹדִים אֲנַֽחְנוּ לָךְ שָׁאַתָּה הוּא יְהֹוָה אֱלֹהֵֽינוּ וֵאלֹהֵי אֲבוֹתֵֽינוּ לְעוֹלָם וָעֶד צוּר חַיֵּֽינוּ מָגֵן יִשְׁעֵֽנוּ אַתָּה הוּא לְדוֹר וָדוֹר נֽוֹדֶה לְּךָ וּנְסַפֵּר תְּהִלָּתֶֽךָ עַל־חַיֵּֽינוּ הַמְּ֒סוּרִים בְּיָדֶֽךָ וְעַל נִשְׁמוֹתֵֽינוּ הַפְּ֒קוּדוֹת לָךְ וְעַל נִסֶּֽיךָ שֶׁבְּכָל יוֹם עִמָּֽנוּ וְעַל נִפְלְ֒אוֹתֶֽיךָ וְטוֹבוֹתֶֽיךָ שֶׁבְּ֒כָל עֵת עֶֽרֶב וָבֹֽקֶר וְצָהֳרָֽיִם הַטּוֹב כִּי לֹא כָלוּ רַחֲמֶֽיךָ וְהַמְ֒רַחֵם כִּי לֹא תַֽמּוּ חֲסָדֶֽיךָ מֵעוֹלָם קִוִּֽינוּ לָךְ:",
                                english: "We are thankful to You that You Adonoy are our God and the God of our fathers forever; Rock of our lives, You are the Shield of our deliverance in every generation. We will give thanks to You and recount Your praise, for our lives which are committed into Your hand, and for our souls which are entrusted to You, and for Your miracles of every day with us, and for Your wonders and benefactions at all times— evening, morning and noon. (You are) The Beneficent One— for Your compassion is never withheld; And (You are) the Merciful One— for Your kindliness never ceases; we have always placed our hope in You.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "וְעַל־כֻּלָּם יִתְבָּרַךְ וְיִתְרוֹמַם שִׁמְךָ מַלְכֵּֽנוּ תָּמִיד לְעוֹלָם וָעֶד: וְכֹל הַחַיִּים יוֹדֽוּךָ סֶּֽלָה וִיהַלְ֒לוּ אֶת־שִׁמְךָ בֶּאֱמֶת הָאֵל יְשׁוּעָתֵֽנוּ וְעֶזְרָתֵֽנוּ סֶֽלָה: בָּרוּךְ אַתָּה יְהֹוָה הַטּוֹב שִׁמְךָ וּלְךָ נָאֶה לְהוֹדוֹת:",
                                english: "And for all the foregoing may Your Name, our King, constantly be blessed and extolled, forever and ever. And all the living shall thank You forever and praise Your Name with sincerity — the Almighty, Who is our deliverance and our help forever. Blessed are You, Adonoy; Your Name is The Beneficent and You it is fitting to praise.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "שָׁלוֹם רָב עַל יִשְׂרָאֵל עַמְּ֒ךָ תָּשִׂים לְעוֹלָם כִּי אַתָּה הוּא מֶֽלֶךְ אָדוֹן לְכָל־הַשָּׁלוֹם וְטוֹב בְּעֵינֶֽיךָ לְבָרֵךְ אֶת־עַמְּ֒ךָ יִשְׂרָאֵל בְּכָל־עֵת וּבְכָל־שָׁעָה בִּשְׁלוֹמֶֽךָ: בָּרוּךְ אַתָּה יְהֹוָה הַמְבָרֵךְ אֶת־עַמּוֹ יִשְׂרָאֵל בַּשָּׁלוֹם:",
                                english: "Bestow abundant peace upon Israel, Your people, forever. For You are King, the Master of all peace. And may it be good in Your sight to bless us and to bless Your people Israel, at all times and at every moment with Your peace. Blessed are You, Adonoy, Who blesses His people Israel with peace.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "יִהְיוּ לְרָצוֹן אִמְרֵי פִי וְהֶגְיוֹן לִבִּי לְפָנֶֽיךָ יְהֹוָה צוּרִי וְגוֹאֲלִי:",
                                english: "May the words of my mouth and the thoughts of my heart be acceptable before You, Adonoy, my Rock and my Redeemer.",
                                showEnglish: showEnglish
                            )
                            
                            PrayerBlock(
                                hebrew: "אֱלֹהַי נְצוֹר לְשׁוֹנִי מֵרָע וּשְׂפָתַי מִדַּבֵּר מִרְמָה. וְלִמְקַלְ֒לַי נַפְשִׁי תִדּוֹם וְנַפְשִׁי כֶּעָפָר לַכֹּל תִּהְיֶה. פְּתַח לִבִּי בְּתוֹרָתֶֽךָ וּבְמִצְוֹתֶֽיךָ תִּרְדֹּף נַפְשִׁי. וְכֹל הַחוֹשְׁ֒בִים עָלַי רָעָה מְהֵרָה הָפֵר עֲצָתָם וְקַלְקֵל מַחֲשַׁבְתָּם: עֲשֵׂה לְמַֽעַן שְׁמֶֽךָ עֲשֵׂה לְמַֽעַן יְמִינֶֽךָ עֲשֵׂה לְמַֽעַן קְדֻשָּׁתֶֽךָ עֲשֵׂה לְמַֽעַן תּוֹרָתֶֽךָ. לְמַֽעַן יֵחָלְ֒צוּן יְדִידֶֽיךָ הוֹשִֽׁיעָה יְמִינְ֒ךָ וַעֲנֵֽנִי: יִהְיוּ לְרָצוֹן אִמְרֵי פִי וְהֶגְיוֹן לִבִּי לְפָנֶֽיךָ יְהֹוָה צוּרִי וְגוֹאֲלִי: עֹשֶׂה שָׁלוֹם בִּמְרוֹמָיו הוּא יַעֲשֶׂה שָׁלוֹם עָלֵֽינוּ וְעַל כָּל־יִשְׂרָאֵל וְאִמְרוּ אָמֵן:",
                                english: "My God, guard my tongue from evil and my lips from speaking deceitfully. May my soul be unresponsive to those who curse me; and let my soul be like dust to all. Open my heart to Your Torah and let my soul pursue Your commandments. And all who plan evil against me, quickly annul their counsel and frustrate their intention. Act for the sake of Your right hand. Act for the sake of Your holiness. Act for the sake of Your Torah. In order that Your loved ones be released, deliver [with] Your right hand and answer me. May the words of my mouth and the thoughts of my heart be acceptable before You Adonoy, my Rock and my Redeemer. He Who makes peace in His high heavens may He make peace upon us and upon all Israel and say Amein.",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "עָלֵֽינוּ לְשַׁבֵּֽחַ לַאֲדוֹן הַכֹּל לָתֵת גְּדֻלָּה לְיוֹצֵר בְּרֵאשִׁית שֶׁלֺּא עָשָֽׂנוּ כְּגוֹיֵי הָאֲרָצוֹת וְלֺא שָׂמָֽנוּ כְּמִשְׁפְּחוֹת הָאֲדָמָה שֶׁלֺּא שָׂם חֶלְקֵֽנוּ כָּהֶם וְגוֹרָלֵֽנוּ כְּכָל הֲמוֹנָם: שֶׁהֵם מִשְׁתַּחֲוִים לָהֶֽבֶל וָרִיק וּמִתְפַּלְּ֒לִים אֶל אֵל לֹא יוֹשִֽׁיעַ, וַאֲנַֽחְנוּ כּוֹרְ֒עִים וּמִשְׁתַּחֲוִים וּמוֹדִים לִפְנֵי מֶֽלֶךְ מַלְכֵי הַמְּ֒לָכִים הַקָּדוֹשׁ בָּרוּךְ הוּא, שֶׁהוּא נוֹטֶה שָׁמַֽיִם וְיוֹסֵד אָֽרֶץ, וּמוֹשַׁב יְקָרוֹ בַּשָּׁמַֽיִם מִמַּֽעַל, וּשְׁ֒כִינַת עֻזּוֹ בְּגָבְ֒הֵי מְרוֹמִים, הוּא אֱלֺהֵֽינוּ אֵין עוֹד, אֱמֶת מַלְכֵּֽנוּ אֶֽפֶס זוּלָתוֹ כַּכָּתוּב בְּתוֹרָתוֹ וְיָדַעְתָּ הַיּוֹם וַהֲשֵׁבֹתָ אֶל לְבָבֶֽךָ כִּי יְהֹוָה הוּא הָאֱלֺהִים בַּשָּׁמַֽיִם מִמַּֽעַל וְעַל הָאָֽרֶץ מִתָּֽחַת אֵין עוֹד:",
                                english: "It is our obligation to praise the Master of all, to ascribe greatness to the Creator of the world in the beginning: that He has not made us like the nations of the lands, and has not positioned us like the families of the earth; that He has not assigned our portion like theirs, nor our lot like that of all their multitudes. For they prostrate themselves to vanity and nothingness, and pray to a god that cannot deliver. But we bow, prostrate ourselves, and offer thanks before the Supreme King of Kings, the Holy One blessed is He, Who spreads the heavens, and establishes the earth, and the seat of His glory is in heaven above, and the abode of His invincible might is in the loftiest heights. He is our God, there is nothing else. Our King is true, all else is insignificant, as it is written in His Torah: And you shall know this day and take into Your heart that Adonoy is God in the heavens above and upon the earth below; there is nothing else.",
                                showEnglish: showEnglish
                            )

                            PrayerBlock(
                                hebrew: "עַל כֵּן נְקַוֶּה לְךָ יְהֹוָה אֱלֺהֵֽינוּ לִרְאוֹת מְהֵרָה בְּתִפְאֶֽרֶת עֻזֶּֽךָ לְהַעֲבִיר גִּלּוּלִים מִן הָאָֽרֶץ וְהָאֱלִילִים כָּרוֹת יִכָּרֵתוּן לְתַקֵּן עוֹלָם בְּמַלְכוּת שַׁדַּי וְכָל בְּנֵי בָשָׂר יִקְרְאוּ בִשְׁ֒מֶֽךָ, לְהַפְנוֹת אֵלֶֽיךָ כָּל רִשְׁ֒עֵי אָֽרֶץ, יַכִּֽירוּ וְיֵדְ֒עוּ כָּל יוֹשְׁ֒בֵי תֵבֵל כִּי לְךָ תִכְרַע כָּל בֶּֽרֶךְ תִּשָּׁבַע כָּל לָשׁוֹן: לְפָנֶֽיךָ יְהֹוָה אֱלֺהֵֽינוּ יִכְרְעוּ וְיִפֹּֽלוּ, וְלִכְ֒בוֹד שִׁמְךָ יְקָר יִתֵּֽנוּ, וִיקַבְּ֒לוּ כֻלָּם אֶת עֹל מַלְכוּתֶֽךָ, וְתִמְלֺךְ עֲלֵיהֶם מְהֵרָה לְעוֹלָם וָעֶד, כִּי הַמַּלְכוּת שֶׁלְּ֒ךָ הִיא וּלְעֽוֹלְ֒מֵי עַד תִּמְלוֹךְ בְּכָבוֹד, כַּכָּתוּב בְּתוֹרָתֶֽךָ יְהֹוָה יִמְלֺךְ לְעֹלָם וָעֶד: וְנֶאֱמַר וְהָיָה יְהֹוָה לְמֶֽלֶךְ עַל כָּל הָאָֽרֶץ בַּיּוֹם הַהוּא יִהְיֶה יְהֹוָה אֶחָד וּשְׁמוֹ אֶחָד:",
                                english: "We therefore put our hope in You, Adonoy our God, to soon behold the glory of Your might in banishing idolatry from the earth, and the false gods will be utterly exterminated to perfect the world as the kingdom of Shadai. And all mankind will invoke Your Name, to turn back to You, all the wicked of the earth. They will realize and know, all the inhabitants of the world, that to You, every knee must bend, every tongue must swear allegiance to You. Before You, Adonoy, our God, they will bow and prostrate themselves, and to the glory of Your Name give honor. And they will all accept upon themselves the yoke of Your kingdom, and You will reign over them, soon, forever and ever. For the kingdom is Yours, and to all eternity You will reign in glory, as it is written in Your Torah: Adonoy will reign forever and ever. And it is said: And Adonoy will be King over the whole earth; on that day Adonoy will be One and His Name One.",
                                showEnglish: showEnglish
                            )
                        }
                        .environment(\.siddurFontScale, CGFloat(textScale))
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.2) : .white)
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 15, x: 0, y: 4)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }

                EastCompassBadge()
                    .padding(.trailing, 18)
                    .padding(.bottom, 22)
            }
            .navigationTitle("Maariv")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}


#Preview {
    SiddurView()
}
