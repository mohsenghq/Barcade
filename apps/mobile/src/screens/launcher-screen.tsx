import React from "react";
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
} from "react-native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import type { RootStackParamList } from "../../App";
import type { ChessProfile } from "@starcade/core";

type Props = NativeStackScreenProps<RootStackParamList, "Launcher"> & {
  profile: ChessProfile;
};

const COLORS = {
  indigoDeep: "#130E24",
  indigo: "#1B1533",
  indigoLight: "#241A45",
  coral: "#FF5A5F",
  cyan: "#29E0E0",
  gold: "#FFC53D",
  mint: "#3DDC97",
  cosmic: "#F6F3FF",
  surface: "rgba(255,255,255,0.08)",
  surfaceStrong: "rgba(255,255,255,0.14)",
  surfaceStroke: "rgba(255,255,255,0.18)",
};

export function LauncherScreen({ navigation, profile }: Props) {
  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.title}>Starcade</Text>

      <TouchableOpacity
        style={styles.chessCard}
        activeOpacity={0.8}
        onPress={() => {
          // Show mode selection
          navigation.navigate("Chess", { mode: "hotseat" });
        }}
      >
        <View style={styles.chessIcon}>
          <Text style={styles.chessIconText}>♜</Text>
        </View>
        <View style={styles.chessInfo}>
          <Text style={styles.chessTitle}>Chess</Text>
          <Text style={styles.chessWins}>Wins: {profile.wins}</Text>
        </View>
      </TouchableOpacity>

      <Text style={styles.moreSoon}>More games coming soon</Text>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.indigoDeep,
    padding: 20,
  },
  title: {
    fontSize: 32,
    fontWeight: "800",
    fontFamily: "Nunito",
    color: COLORS.cosmic,
    marginTop: 8,
  },
  chessCard: {
    flexDirection: "row",
    alignItems: "center",
    gap: 14,
    backgroundColor: COLORS.surfaceStrong,
    borderWidth: 1,
    borderColor: COLORS.surfaceStroke,
    borderRadius: 20,
    padding: 20,
    marginTop: 28,
  },
  chessIcon: {
    width: 48,
    height: 48,
    borderRadius: 12,
    backgroundColor: `${COLORS.mint}30`,
    alignItems: "center",
    justifyContent: "center",
  },
  chessIconText: {
    fontSize: 28,
    color: COLORS.mint,
  },
  chessInfo: {
    flex: 1,
  },
  chessTitle: {
    fontSize: 16,
    fontWeight: "700",
    fontFamily: "Nunito",
    color: COLORS.cosmic,
  },
  chessWins: {
    fontSize: 12,
    color: `${COLORS.cosmic}90`,
    marginTop: 2,
  },
  moreSoon: {
    textAlign: "center",
    fontSize: 14,
    color: `${COLORS.cosmic}90`,
    marginTop: 18,
  },
});
