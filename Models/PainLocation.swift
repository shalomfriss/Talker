import Foundation

enum PainLocation: String, CaseIterable, Hashable, Identifiable {
    case head, neck, chest, stomach, leftArm, rightArm, leftLeg, rightLeg, upperBack, lowerBack
    case forehead, eyes, ears, teeth, throat
    case leftShoulder, rightShoulder, leftHand, rightHand
    case leftKnee, rightKnee, leftFoot, rightFoot
    case ribs, lowerBelly

    var id: String { rawValue }

    var broadArea: PainLocation? {
        switch self {
        case .forehead, .eyes, .ears, .teeth: .head
        case .throat: .neck
        case .leftShoulder, .leftHand: .leftArm
        case .rightShoulder, .rightHand: .rightArm
        case .leftKnee, .leftFoot: .leftLeg
        case .rightKnee, .rightFoot: .rightLeg
        case .ribs: .chest
        case .lowerBelly: .stomach
        default: nil
        }
    }

    static func toggled(_ location: PainLocation, in selected: Set<PainLocation>) -> Set<PainLocation> {
        var result = selected
        if result.contains(location) {
            result.remove(location)
        } else {
            if let broadArea = location.broadArea {
                result.remove(broadArea)
            } else {
                result.subtract(Self.allCases.filter { $0.broadArea == location })
            }
            result.insert(location)
        }
        return result
    }

    func label(language: String) -> String {
        switch (self, language == "es") {
        case (.head, false): "Head"
        case (.head, true): "Cabeza"
        case (.neck, false): "Neck"
        case (.neck, true): "Cuello"
        case (.chest, false): "Chest"
        case (.chest, true): "Pecho"
        case (.stomach, false): "Stomach"
        case (.stomach, true): "Estómago"
        case (.leftArm, false): "Left arm"
        case (.leftArm, true): "Brazo izquierdo"
        case (.rightArm, false): "Right arm"
        case (.rightArm, true): "Brazo derecho"
        case (.leftLeg, false): "Left leg"
        case (.leftLeg, true): "Pierna izquierda"
        case (.rightLeg, false): "Right leg"
        case (.rightLeg, true): "Pierna derecha"
        case (.upperBack, false): "Upper back"
        case (.upperBack, true): "Espalda alta"
        case (.lowerBack, false): "Lower back"
        case (.lowerBack, true): "Espalda baja"
        case (.forehead, false): "Forehead"
        case (.forehead, true): "Frente"
        case (.eyes, false): "Eyes"
        case (.eyes, true): "Ojos"
        case (.ears, false): "Ears"
        case (.ears, true): "Orejas"
        case (.teeth, false): "Teeth"
        case (.teeth, true): "Dientes"
        case (.throat, false): "Throat"
        case (.throat, true): "Garganta"
        case (.leftShoulder, false): "Left shoulder"
        case (.leftShoulder, true): "Hombro izquierdo"
        case (.rightShoulder, false): "Right shoulder"
        case (.rightShoulder, true): "Hombro derecho"
        case (.leftHand, false): "Left hand"
        case (.leftHand, true): "Mano izquierda"
        case (.rightHand, false): "Right hand"
        case (.rightHand, true): "Mano derecha"
        case (.leftKnee, false): "Left knee"
        case (.leftKnee, true): "Rodilla izquierda"
        case (.rightKnee, false): "Right knee"
        case (.rightKnee, true): "Rodilla derecha"
        case (.leftFoot, false): "Left foot"
        case (.leftFoot, true): "Pie izquierdo"
        case (.rightFoot, false): "Right foot"
        case (.rightFoot, true): "Pie derecho"
        case (.ribs, false): "Ribs"
        case (.ribs, true): "Costillas"
        case (.lowerBelly, false): "Lower belly"
        case (.lowerBelly, true): "Parte baja del abdomen"
        }
    }

    func messagePhrase(language: String) -> String {
        switch (self, language == "es") {
        case (.head, false): "my head"
        case (.head, true): "la cabeza"
        case (.neck, false): "my neck"
        case (.neck, true): "el cuello"
        case (.chest, false): "my chest"
        case (.chest, true): "el pecho"
        case (.stomach, false): "my stomach"
        case (.stomach, true): "el estómago"
        case (.leftArm, false): "my left arm"
        case (.leftArm, true): "el brazo izquierdo"
        case (.rightArm, false): "my right arm"
        case (.rightArm, true): "el brazo derecho"
        case (.leftLeg, false): "my left leg"
        case (.leftLeg, true): "la pierna izquierda"
        case (.rightLeg, false): "my right leg"
        case (.rightLeg, true): "la pierna derecha"
        case (.upperBack, false): "my upper back"
        case (.upperBack, true): "la parte alta de la espalda"
        case (.lowerBack, false): "my lower back"
        case (.lowerBack, true): "la parte baja de la espalda"
        case (.forehead, false): "my forehead"
        case (.forehead, true): "la frente"
        case (.eyes, false): "my eyes"
        case (.eyes, true): "los ojos"
        case (.ears, false): "my ears"
        case (.ears, true): "las orejas"
        case (.teeth, false): "my teeth"
        case (.teeth, true): "los dientes"
        case (.throat, false): "my throat"
        case (.throat, true): "la garganta"
        case (.leftShoulder, false): "my left shoulder"
        case (.leftShoulder, true): "el hombro izquierdo"
        case (.rightShoulder, false): "my right shoulder"
        case (.rightShoulder, true): "el hombro derecho"
        case (.leftHand, false): "my left hand"
        case (.leftHand, true): "la mano izquierda"
        case (.rightHand, false): "my right hand"
        case (.rightHand, true): "la mano derecha"
        case (.leftKnee, false): "my left knee"
        case (.leftKnee, true): "la rodilla izquierda"
        case (.rightKnee, false): "my right knee"
        case (.rightKnee, true): "la rodilla derecha"
        case (.leftFoot, false): "my left foot"
        case (.leftFoot, true): "el pie izquierdo"
        case (.rightFoot, false): "my right foot"
        case (.rightFoot, true): "el pie derecho"
        case (.ribs, false): "my ribs"
        case (.ribs, true): "las costillas"
        case (.lowerBelly, false): "my lower belly"
        case (.lowerBelly, true): "la parte baja del abdomen"
        }
    }
}
