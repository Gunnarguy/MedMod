import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var patients: [PatientProfile]

    var body: some View {
        EHRMainShellView()
            .onAppear {
                if patients.isEmpty {
                    addMockData()
                }
            }
    }

    // swiftlint:disable function_body_length
    private func addMockData() {
        // ──────────────────────────────────────────────
        // MARK: – Patients
        // ──────────────────────────────────────────────

        let janeDoe = PatientProfile(firstName: "Jane", lastName: "Doe",
            dateOfBirth: Date(timeIntervalSince1970: 181872000), // Oct 7 1975
            gender: "Female", isSmoker: true)

        let mariaSantos = PatientProfile(firstName: "Maria", lastName: "Santos",
            dateOfBirth: Date(timeIntervalSince1970: 315532800), // Jan 1 1980
            gender: "Female", isSmoker: false)

        let robertChen = PatientProfile(firstName: "Robert", lastName: "Chen",
            dateOfBirth: Date(timeIntervalSince1970: 86400000), // Sep 9 1972
            gender: "Male", isSmoker: false)

        let sarahJohnson = PatientProfile(firstName: "Sarah", lastName: "Johnson",
            dateOfBirth: Date(timeIntervalSince1970: 631152000), // Jan 1 1990
            gender: "Female", isSmoker: false)

        let davidWilliams = PatientProfile(firstName: "David", lastName: "Williams",
            dateOfBirth: Date(timeIntervalSince1970: 473385600), // Jan 1 1985
            gender: "Male", isSmoker: true)

        // ──────────────────────────────────────────────
        // MARK: – Jane Doe — BCC history, hyperlipidemia
        // ──────────────────────────────────────────────

        let janeMed1 = LocalMedication(rxID: "RX-001", medicationName: "Simvastatin 20mg",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 30),
            quantityInfo: "Take 1 tablet daily at bedtime", refills: 2)
        let janeMed2 = LocalMedication(rxID: "RX-002", medicationName: "Fluorouracil 5% Cream",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 60),
            quantityInfo: "Apply to affected area twice daily x 4 weeks", refills: 0)
        let janeMed3 = LocalMedication(rxID: "RX-003", medicationName: "Tretinoin 0.05% Cream",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 90),
            quantityInfo: "Apply thin layer to face nightly", refills: 3)

        let janeRec1 = LocalClinicalRecord(
            recordID: "REC-001", dateRecorded: Date().addingTimeInterval(-86400 * 365),
            conditionName: "Basal Cell Carcinoma", status: "Final", isHiddenFromPortal: false,
            ccHPI: "Patient presents with a pearly papule on the right upper extremity noted during routine skin exam. Lesion has been present for approximately 6 months with intermittent bleeding. Patient reports occasional itching but no pain. History of significant sun exposure as a lifeguard in her 20s.",
            reviewOfSystems: "Denies fever, chills, weight loss, fatigue, or night sweats. No new lesions noted by patient.",
            examFindings: "3mm pearly, translucent papule with telangiectasia on the right dorsal forearm. Well-circumscribed borders. No ulceration currently. No palpable lymphadenopathy in axillary or epitrochlear nodes.",
            impressionsAndPlan: "Basal Cell Carcinoma — nodular subtype. Recommend surgical excision with 4mm margins. Referral to Mohs surgery if margins not clear on pathology. Follow-up in 6 weeks post-excision. Discussed sun protection, daily SPF 50+. Patient verbalized understanding.",
            affectedAnatomicalZones: ["right_upper_extremity"],
            providerSignature: "Dr. Smith, MD")

        let janeRec2 = LocalClinicalRecord(
            recordID: "REC-002", dateRecorded: Date().addingTimeInterval(-86400 * 180),
            conditionName: "Actinic Keratosis", status: "Final", isHiddenFromPortal: false,
            ccHPI: "Multiple rough, scaly patches on the forehead and scalp identified during comprehensive skin exam. Patient reports these have been present for 2-3 months and are mildly tender when rubbed.",
            reviewOfSystems: "Denies bleeding from lesions. Reports occasional mild headaches, unrelated.",
            examFindings: "Three erythematous, rough, scaly papules on the forehead measuring 4mm, 6mm, and 3mm. Two similar lesions on the vertex scalp. All lesions have a sandpaper-like texture on palpation. No induration or ulceration.",
            impressionsAndPlan: "Actinic Keratoses, multiple — forehead and scalp. Cryotherapy applied to all 5 lesions today. Prescribed Fluorouracil 5% cream for field treatment of the forehead. Return in 8 weeks to assess treatment response. If lesions persist, consider biopsy to rule out SCC.",
            affectedAnatomicalZones: ["forehead", "scalp"],
            providerSignature: "Dr. Smith, MD")

        let janeRec3 = LocalClinicalRecord(
            recordID: "REC-003", dateRecorded: Date().addingTimeInterval(-86400 * 30),
            conditionName: "Annual Skin Exam", status: "Final", isHiddenFromPortal: false,
            ccHPI: "Annual comprehensive skin examination. Patient with history of BCC (excised 12 months ago) and actinic keratoses. Currently using tretinoin 0.05% nightly. Reports good compliance with sun protection.",
            reviewOfSystems: "No new moles or changing lesions noted by patient. Denies pruritus, rashes, or skin pain.",
            examFindings: "Full body skin exam performed. BCC excision site on right forearm: well-healed linear scar, no recurrence. Forehead AKs largely resolved after fluorouracil course — one residual 2mm AK on right forehead. Scattered lentigines on bilateral upper extremities. One 5mm symmetric, uniformly brown nevus on left scapula — stable per patient. No concerning lesions identified.",
            impressionsAndPlan: "1. BCC excision site — no recurrence, continue annual surveillance. 2. Residual AK on right forehead — cryotherapy applied today. 3. Continue tretinoin 0.05% nightly for photoaging and AK prophylaxis. 4. Return in 12 months for annual exam, sooner if new or changing lesions.",
            affectedAnatomicalZones: ["right_upper_extremity", "forehead"],
            providerSignature: "Dr. Smith, MD")

        let janeAppt1 = Appointment(appointmentID: "APT-001",
            scheduledTime: Date().addingTimeInterval(86400 * 2),
            reasonForVisit: "6-week post-cryo check", status: "Scheduled")
        let janeAppt2 = Appointment(appointmentID: "APT-002",
            scheduledTime: Date().addingTimeInterval(86400 * 365),
            reasonForVisit: "Annual skin exam", status: "Scheduled")

        // ──────────────────────────────────────────────
        // MARK: – Maria Santos — Acne, early rosacea
        // ──────────────────────────────────────────────

        let mariaMed1 = LocalMedication(rxID: "RX-004", medicationName: "Tretinoin 0.025% Cream",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 14),
            quantityInfo: "Apply thin layer to face nightly", refills: 3)
        let mariaMed2 = LocalMedication(rxID: "RX-005", medicationName: "Benzoyl Peroxide 5% Gel",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 14),
            quantityInfo: "Apply to affected areas every morning", refills: 5)
        let mariaMed3 = LocalMedication(rxID: "RX-006", medicationName: "Doxycycline 100mg",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 14),
            quantityInfo: "Take 1 capsule twice daily with food x 3 months", refills: 0)
        let mariaMed4 = LocalMedication(rxID: "RX-007", medicationName: "Metronidazole 0.75% Gel",
            writtenBy: "Dr. Jones", writtenDate: Date().addingTimeInterval(-86400 * 7),
            quantityInfo: "Apply thin layer to nose and cheeks twice daily", refills: 2)

        let mariaRec1 = LocalClinicalRecord(
            recordID: "REC-004", dateRecorded: Date().addingTimeInterval(-86400 * 90),
            conditionName: "Acne Vulgaris", status: "Final", isHiddenFromPortal: false,
            ccHPI: "25-year-old female presents with moderate inflammatory acne on face and upper back. Reports onset approximately 3 months ago coinciding with starting a new job. Has tried OTC benzoyl peroxide wash with minimal improvement. No prior prescription treatment. Denies any new cosmetics or dietary changes.",
            reviewOfSystems: "Reports mild stress and occasional insomnia. Denies fevers, weight changes, or menstrual irregularity.",
            examFindings: "Bilateral cheeks: numerous open and closed comedones with 15-20 inflammatory papules and 3-4 pustules. Forehead: scattered closed comedones. Upper back: 5-6 inflammatory papules. No nodules or cysts. No scarring noted. Mild post-inflammatory hyperpigmentation on left cheek.",
            impressionsAndPlan: "Acne Vulgaris, moderate inflammatory. 1. Start tretinoin 0.025% cream nightly (counsel on purging phase, sun sensitivity). 2. Continue benzoyl peroxide 5% gel AM. 3. Add doxycycline 100mg BID x 3 months for inflammatory component. 4. Follow-up in 8 weeks to assess response.",
            affectedAnatomicalZones: ["left_cheek", "right_cheek", "forehead"],
            providerSignature: "Dr. Smith, MD")

        let mariaRec2 = LocalClinicalRecord(
            recordID: "REC-005", dateRecorded: Date().addingTimeInterval(-86400 * 7),
            conditionName: "Rosacea", status: "Preliminary", isHiddenFromPortal: false,
            ccHPI: "Patient returns for 8-week acne follow-up. Reports significant improvement in acne — fewer breakouts, comedones clearing. However, notes persistent redness across nose and central cheeks that worsens with hot beverages, spicy food, and after exercise. Occasional stinging sensation.",
            reviewOfSystems: "Denies eye irritation, blurry vision. Reports occasional facial flushing lasting 10-15 minutes.",
            examFindings: "Acne: marked improvement — 3-4 residual comedones on forehead, 2 small papules on right cheek. Rosacea: diffuse centrofacial erythema involving nose and medial cheeks. Scattered telangiectasias on nasal ala. No papulopustular lesions of rosacea at this time. No ocular involvement.",
            impressionsAndPlan: "1. Acne Vulgaris — good response. Taper doxycycline to 100mg daily x 1 month then discontinue. Continue topical retinoid and BP. 2. Rosacea, erythematotelangiectatic subtype — new diagnosis. Start metronidazole 0.75% gel BID. Counsel on trigger avoidance (sun, heat, alcohol, spicy foods). Consider brimonidine for acute flushing episodes if needed. Follow-up in 6 weeks.",
            affectedAnatomicalZones: ["facial_mesh_nose", "left_cheek", "right_cheek"],
            providerSignature: "Dr. Jones, MD")

        let mariaAppt1 = Appointment(appointmentID: "APT-003",
            scheduledTime: Date().addingTimeInterval(86400 * 5),
            reasonForVisit: "Acne/rosacea follow-up", status: "Scheduled")
        let mariaAppt2 = Appointment(appointmentID: "APT-004",
            scheduledTime: Date().addingTimeInterval(86400 * 42),
            reasonForVisit: "Rosacea 6-week check", status: "Scheduled")

        // ──────────────────────────────────────────────
        // MARK: – Robert Chen — Psoriasis, melanoma history
        // ──────────────────────────────────────────────

        let robertMed1 = LocalMedication(rxID: "RX-008", medicationName: "Clobetasol 0.05% Ointment",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 45),
            quantityInfo: "Apply to plaques twice daily x 2 weeks, then weekends only", refills: 1)
        let robertMed2 = LocalMedication(rxID: "RX-009", medicationName: "Calcipotriene 0.005% Cream",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 45),
            quantityInfo: "Apply to affected areas daily", refills: 3)
        let robertMed3 = LocalMedication(rxID: "RX-010", medicationName: "Methotrexate 15mg",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 20),
            quantityInfo: "Take once weekly on Mondays with folic acid", refills: 5)
        let robertMed4 = LocalMedication(rxID: "RX-011", medicationName: "Folic Acid 1mg",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 20),
            quantityInfo: "Take 1 tablet daily except Mondays", refills: 5)

        let robertRec1 = LocalClinicalRecord(
            recordID: "REC-006", dateRecorded: Date().addingTimeInterval(-86400 * 730),
            conditionName: "Melanoma In Situ", status: "Final", isHiddenFromPortal: false,
            ccHPI: "Patient referred by PCP for evaluation of a changing mole on the left upper back. Reports the lesion has been darkening and growing over the past 4 months. No bleeding or itching. Family history: father had melanoma at age 60.",
            reviewOfSystems: "Denies weight loss, fatigue, bone pain, or neurological symptoms.",
            examFindings: "Left scapular region: 8mm irregularly bordered, asymmetric macule with variegated brown-black coloration. ABCDE criteria: Asymmetry (+), Border irregularity (+), Color variation (+), Diameter >6mm (+), Evolution (+). No satellite lesions. No palpable lymphadenopathy in axillary or cervical chains. Dermatoscopy: irregular pigment network, regression structures, blue-white veil absent.",
            impressionsAndPlan: "Melanoma In Situ — clinical suspicion high. Excisional biopsy performed today with 2mm margins. Rush pathology ordered. If confirmed melanoma in situ, will need wide local excision with 5mm margins. Sentinel lymph node biopsy not indicated for in situ disease. Urgent follow-up in 1 week for path results. Full body photography at next visit.",
            affectedAnatomicalZones: ["left_upper_extremity"],
            providerSignature: "Dr. Smith, MD")

        let robertRec2 = LocalClinicalRecord(
            recordID: "REC-007", dateRecorded: Date().addingTimeInterval(-86400 * 700),
            conditionName: "Melanoma In Situ — Post-Excision", status: "Final", isHiddenFromPortal: false,
            ccHPI: "Follow-up for melanoma in situ excision. Pathology confirmed melanoma in situ, lentigo maligna type. Margins clear on excisional biopsy. Patient here for wide local excision.",
            examFindings: "Left scapular biopsy site: well-healing, no signs of infection. Wide local excision performed with 5mm surgical margins. Specimen sent to pathology. No new suspicious lesions on limited exam.",
            impressionsAndPlan: "Wide local excision of melanoma in situ — completed. Await final pathology for margin confirmation. Established q6-month full body skin exams for 2 years, then annual. Patient counseled on sun protection, monthly self-exams, and warning signs of recurrence.",
            affectedAnatomicalZones: ["left_upper_extremity"],
            providerSignature: "Dr. Smith, MD")

        let robertRec3 = LocalClinicalRecord(
            recordID: "REC-008", dateRecorded: Date().addingTimeInterval(-86400 * 45),
            conditionName: "Plaque Psoriasis", status: "Final", isHiddenFromPortal: false,
            ccHPI: "Patient presents with worsening psoriasis flare over the past 2 months. Reports thick, itchy plaques on bilateral elbows, knees, and scalp. Has been using OTC moisturizers only. PASI score estimated at 12. New joint stiffness in fingers and toes for 3 weeks — concerning for psoriatic arthritis.",
            reviewOfSystems: "Reports morning stiffness lasting 45 minutes in bilateral hands. Mild fatigue. Denies nail changes, eye redness, or GI symptoms.",
            examFindings: "Well-demarcated, erythematous plaques with thick silvery scale on bilateral elbows (8cm x 6cm), bilateral knees (5cm x 4cm), and scalp (diffuse involvement of vertex and occipital regions). BSA approximately 8%. Nails: fine pitting on bilateral thumbnails, no onycholysis. Joints: mild dactylitis of right 3rd toe. No enthesitis detected. Skin of the face, trunk clear.",
            impressionsAndPlan: "1. Plaque Psoriasis — moderate, worsening. Start clobetasol 0.05% ointment for acute flare (2 weeks active, then weekends). Add calcipotriene daily for maintenance. 2. Possible Psoriatic Arthritis — start methotrexate 15mg weekly with folic acid supplementation. Order CBC, CMP, hepatitis panel before first dose. 3. Refer to rheumatology for joint evaluation. 4. Follow-up in 6 weeks for methotrexate labs and response assessment.",
            affectedAnatomicalZones: ["left_upper_extremity", "right_upper_extremity", "scalp"],
            providerSignature: "Dr. Smith, MD")

        let robertAppt1 = Appointment(appointmentID: "APT-005",
            scheduledTime: Date().addingTimeInterval(86400 * 3),
            reasonForVisit: "Psoriasis — methotrexate labs review", status: "Scheduled")
        let robertAppt2 = Appointment(appointmentID: "APT-006",
            scheduledTime: Date().addingTimeInterval(86400 * 180),
            reasonForVisit: "6-month melanoma surveillance", status: "Scheduled")

        // ──────────────────────────────────────────────
        // MARK: – Sarah Johnson — Eczema, contact dermatitis
        // ──────────────────────────────────────────────

        let sarahMed1 = LocalMedication(rxID: "RX-012", medicationName: "Triamcinolone 0.1% Cream",
            writtenBy: "Dr. Jones", writtenDate: Date().addingTimeInterval(-86400 * 60),
            quantityInfo: "Apply to affected areas twice daily x 2 weeks", refills: 2)
        let sarahMed2 = LocalMedication(rxID: "RX-013", medicationName: "Tacrolimus 0.1% Ointment",
            writtenBy: "Dr. Jones", writtenDate: Date().addingTimeInterval(-86400 * 60),
            quantityInfo: "Apply to face and neck twice daily as needed", refills: 3)
        let sarahMed3 = LocalMedication(rxID: "RX-014", medicationName: "Hydroxyzine 25mg",
            writtenBy: "Dr. Jones", writtenDate: Date().addingTimeInterval(-86400 * 60),
            quantityInfo: "Take 1 tablet at bedtime as needed for itch", refills: 1)
        let sarahMed4 = LocalMedication(rxID: "RX-015", medicationName: "Dupilumab 300mg",
            writtenBy: "Dr. Jones", writtenDate: Date().addingTimeInterval(-86400 * 30),
            quantityInfo: "Inject subcutaneously every 2 weeks", refills: 5)
        let sarahMed5 = LocalMedication(rxID: "RX-016", medicationName: "CeraVe Moisturizing Cream",
            writtenBy: "Dr. Jones", writtenDate: Date().addingTimeInterval(-86400 * 60),
            quantityInfo: "Apply liberally after bathing and as needed", refills: 99)

        let sarahRec1 = LocalClinicalRecord(
            recordID: "REC-009", dateRecorded: Date().addingTimeInterval(-86400 * 120),
            conditionName: "Atopic Dermatitis", status: "Final", isHiddenFromPortal: false,
            ccHPI: "30-year-old female with childhood history of eczema, now with severe flare over the past 6 weeks. Reports intense pruritus disrupting sleep (waking 3-4 times nightly). Affecting bilateral antecubital fossae, neck, and periorbital areas. Has been using OTC hydrocortisone 1% with no relief. History of asthma and allergic rhinitis (atopic triad). Current triggers: stress from grad school finals, recent cold weather.",
            reviewOfSystems: "Reports poor sleep quality due to itching. Mild asthma exacerbation — using rescue inhaler 3x/week. Denies eye discharge or visual changes. Reports dry, cracking skin on hands.",
            examFindings: "Bilateral antecubital fossae: erythematous, lichenified plaques with excoriation marks and serous weeping. Neck: diffuse erythema with fine papules and excoriations. Periorbital: mild eczematous changes with Dennie-Morgan infraorbital folds. Hands: xerosis with fissures on bilateral palms. BSA approximately 15%. EASI score: 24 (severe). No signs of secondary infection (no honey crusting, pustules, or lymphangitic streaking).",
            impressionsAndPlan: "Atopic Dermatitis, severe — IGA 4. 1. Triamcinolone 0.1% cream for body areas BID x 2 weeks, then PRN flares. 2. Tacrolimus 0.1% ointment for face/neck areas BID. 3. Hydroxyzine 25mg QHS for nocturnal pruritus. 4. Emollient therapy (CeraVe cream) — soak and smear technique discussed. 5. Given severity and impact on QoL, initiate Dupilumab — loading dose 600mg, then 300mg q2weeks. Prior auth submitted. Follow-up in 4 weeks.",
            affectedAnatomicalZones: ["left_upper_extremity", "right_upper_extremity", "neck"],
            providerSignature: "Dr. Jones, MD")

        let sarahRec2 = LocalClinicalRecord(
            recordID: "REC-010", dateRecorded: Date().addingTimeInterval(-86400 * 30),
            conditionName: "Contact Dermatitis — Nickel", status: "Final", isHiddenFromPortal: false,
            ccHPI: "Patient returns for Dupilumab 4-week check. Reports significant improvement in atopic dermatitis — sleeping through the night, pruritus reduced from 9/10 to 3/10. However, notes a new itchy, blistering rash on the abdomen at the belt buckle line for 5 days. No new detergents or topicals.",
            reviewOfSystems: "Overall improved mood and energy with better sleep. Asthma well-controlled.",
            examFindings: "Atopic dermatitis: marked improvement. Antecubital fossae — mild residual lichen, no active inflammation. Neck and periorbital areas clear. EASI score: 6 (mild). New finding: sharply demarcated, rectangular erythematous plaque with vesicles on periumbilical area corresponding exactly to belt buckle contact. Classic morphology for allergic contact dermatitis.",
            impressionsAndPlan: "1. Atopic Dermatitis — excellent response to Dupilumab. Continue current regimen. EASI improved 24→6. 2. Allergic Contact Dermatitis to nickel — clinical diagnosis. Patch testing to be scheduled for confirmation and extended allergen panel. Counsel: avoid nickel-containing jewelry and belt buckles, use buckle covers or nickel-free alternatives. Triamcinolone 0.1% to the affected area BID x 1 week. Follow-up in 8 weeks.",
            affectedAnatomicalZones: ["chin"],
            providerSignature: "Dr. Jones, MD")

        let sarahAppt1 = Appointment(appointmentID: "APT-007",
            scheduledTime: Date().addingTimeInterval(86400 * 1),
            reasonForVisit: "Dupilumab injection + 8-week check", status: "Scheduled")
        let sarahAppt2 = Appointment(appointmentID: "APT-008",
            scheduledTime: Date().addingTimeInterval(86400 * 14),
            reasonForVisit: "Patch testing — nickel panel", status: "Scheduled")

        // ──────────────────────────────────────────────
        // MARK: – David Williams — Rosacea, skin cancer screening
        // ──────────────────────────────────────────────

        let davidMed1 = LocalMedication(rxID: "RX-017", medicationName: "Ivermectin 1% Cream",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 21),
            quantityInfo: "Apply thin layer to face once daily", refills: 2)
        let davidMed2 = LocalMedication(rxID: "RX-018", medicationName: "Azelaic Acid 15% Gel",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 21),
            quantityInfo: "Apply to affected areas twice daily", refills: 3)
        let davidMed3 = LocalMedication(rxID: "RX-019", medicationName: "Brimonidine 0.33% Gel",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 21),
            quantityInfo: "Apply to face once daily for flushing episodes", refills: 1)
        let davidMed4 = LocalMedication(rxID: "RX-020", medicationName: "Imiquimod 5% Cream",
            writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 10),
            quantityInfo: "Apply to wart at bedtime Mon/Wed/Fri x 8 weeks", refills: 0)

        let davidRec1 = LocalClinicalRecord(
            recordID: "REC-011", dateRecorded: Date().addingTimeInterval(-86400 * 21),
            conditionName: "Rosacea", status: "Final", isHiddenFromPortal: false,
            ccHPI: "41-year-old male presents with persistent facial redness, flushing, and papulopustular lesions for the past 4 months. Reports triggers include alcohol (craft beer), sun exposure, and hot showers. Has tried OTC redness-reducing creams without benefit. Family history of rosacea in mother.",
            reviewOfSystems: "Reports mild eye grittiness and redness in mornings — possible ocular rosacea. Denies visual changes. Occasional headaches.",
            examFindings: "Centrofacial erythema with prominent telangiectasias on bilateral nasal ala and medial cheeks. Approximately 12 inflammatory papules and 4 pustules distributed on cheeks and chin. No comedones (distinguishing from acne). Mild rhinophyma — early thickening of nasal skin. Eyes: bilateral conjunctival injection, mild blepharitis with collarettes on lashes.",
            impressionsAndPlan: "Rosacea, papulopustular subtype with early phymatous changes and ocular involvement. 1. Ivermectin 1% cream daily for papulopustular component. 2. Azelaic acid 15% gel BID as adjunct. 3. Brimonidine 0.33% gel PRN for acute flushing. 4. Trigger counseling: reduce alcohol, use SPF 50+ daily, lukewarm showers. 5. Ophthalmology referral for ocular rosacea — warm compresses and lid hygiene in the interim. 6. Follow-up in 6 weeks.",
            affectedAnatomicalZones: ["facial_mesh_nose", "left_cheek", "right_cheek", "chin"],
            providerSignature: "Dr. Smith, MD")

        let davidRec2 = LocalClinicalRecord(
            recordID: "REC-012", dateRecorded: Date().addingTimeInterval(-86400 * 10),
            conditionName: "Verruca Vulgaris", status: "Final", isHiddenFromPortal: false,
            ccHPI: "Patient returns for rosacea follow-up and also reports a persistent wart on the right hand present for 6 months. Has tried OTC salicylic acid and duct tape with minimal response. The wart is enlarging and now has two satellite lesions nearby.",
            examFindings: "Rosacea: improving — papulopustular component reduced by approximately 60%, erythema mildly improved. Right dorsal hand, 2nd MCP joint: 7mm verrucous papule with characteristic thrombosed capillaries (black dots) and loss of dermatoglyphics. Two 2mm satellite verrucae at adjacent sites.",
            impressionsAndPlan: "1. Rosacea — responding well. Continue current regimen. Reassess in 6 more weeks. 2. Verruca Vulgaris, right hand — cryotherapy applied to all three lesions today (2 freeze-thaw cycles). Additionally prescribing imiquimod 5% cream 3x/week for 8 weeks. Counsel on HPV transmission and handwashing. Return in 4 weeks for retreatment if needed.",
            affectedAnatomicalZones: ["right_upper_extremity"],
            providerSignature: "Dr. Smith, MD")

        let davidRec3 = LocalClinicalRecord(
            recordID: "REC-013", dateRecorded: Date().addingTimeInterval(-86400 * 500),
            conditionName: "Dysplastic Nevus", status: "Final", isHiddenFromPortal: false,
            ccHPI: "Patient presents for full body skin exam. Reports a mole on the upper back that has changed color slightly over the past year. No family history of melanoma. Significant sun exposure history — worked outdoor construction for 10 years. Current smoker.",
            examFindings: "Full body skin exam performed. Left upper back: 6mm asymmetric nevus with slightly irregular borders and two-tone brown coloring. Dermoscopy shows irregular pigment network at periphery but no blue-white veil or regression structures. Multiple acquired nevi scattered on trunk, all appearing banal. No other concerning lesions.",
            impressionsAndPlan: "Dysplastic Nevus, left upper back — mildly atypical appearing. Shave biopsy performed today for histological assessment. Await pathology. If moderately or severely dysplastic, will need re-excision. Baseline total body photography recommended. Return in 7 days for suture removal and path results. Annual skin exams given sun exposure history and atypical nevi.",
            affectedAnatomicalZones: ["left_upper_extremity"],
            providerSignature: "Dr. Smith, MD")

        let davidAppt1 = Appointment(appointmentID: "APT-009",
            scheduledTime: Date().addingTimeInterval(86400 * 7),
            reasonForVisit: "Wart cryo retreatment + rosacea check", status: "Scheduled")
        let davidAppt2 = Appointment(appointmentID: "APT-010",
            scheduledTime: Date().addingTimeInterval(86400 * 0.5),
            reasonForVisit: "Urgent — new rapidly growing lesion", status: "Scheduled")

        // ──────────────────────────────────────────────
        // MARK: – Insert All Entities
        // ──────────────────────────────────────────────

        let allPatients = [janeDoe, mariaSantos, robertChen, sarahJohnson, davidWilliams]
        let allMeds = [janeMed1, janeMed2, janeMed3,
                       mariaMed1, mariaMed2, mariaMed3, mariaMed4,
                       robertMed1, robertMed2, robertMed3, robertMed4,
                       sarahMed1, sarahMed2, sarahMed3, sarahMed4, sarahMed5,
                       davidMed1, davidMed2, davidMed3, davidMed4]
        let allRecords = [janeRec1, janeRec2, janeRec3,
                          mariaRec1, mariaRec2,
                          robertRec1, robertRec2, robertRec3,
                          sarahRec1, sarahRec2,
                          davidRec1, davidRec2, davidRec3]
        let allAppts = [janeAppt1, janeAppt2,
                        mariaAppt1, mariaAppt2,
                        robertAppt1, robertAppt2,
                        sarahAppt1, sarahAppt2,
                        davidAppt1, davidAppt2]

        for p in allPatients { modelContext.insert(p) }
        for m in allMeds { modelContext.insert(m) }
        for r in allRecords { modelContext.insert(r) }
        for a in allAppts { modelContext.insert(a) }

        // ──────────────────────────────────────────────
        // MARK: – Wire Relationships
        // ──────────────────────────────────────────────

        janeDoe.medications = [janeMed1, janeMed2, janeMed3]
        janeDoe.clinicalRecords = [janeRec1, janeRec2, janeRec3]
        janeDoe.appointments = [janeAppt1, janeAppt2]

        mariaSantos.medications = [mariaMed1, mariaMed2, mariaMed3, mariaMed4]
        mariaSantos.clinicalRecords = [mariaRec1, mariaRec2]
        mariaSantos.appointments = [mariaAppt1, mariaAppt2]

        robertChen.medications = [robertMed1, robertMed2, robertMed3, robertMed4]
        robertChen.clinicalRecords = [robertRec1, robertRec2, robertRec3]
        robertChen.appointments = [robertAppt1, robertAppt2]

        sarahJohnson.medications = [sarahMed1, sarahMed2, sarahMed3, sarahMed4, sarahMed5]
        sarahJohnson.clinicalRecords = [sarahRec1, sarahRec2]
        sarahJohnson.appointments = [sarahAppt1, sarahAppt2]

        davidWilliams.medications = [davidMed1, davidMed2, davidMed3, davidMed4]
        davidWilliams.clinicalRecords = [davidRec1, davidRec2, davidRec3]
        davidWilliams.appointments = [davidAppt1, davidAppt2]

        try? modelContext.save()
    }
    // swiftlint:enable function_body_length
}
