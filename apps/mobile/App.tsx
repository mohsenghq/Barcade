import { useEffect, useState } from "react";
import { StatusBar } from "expo-status-bar";
import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import {
  SaveController,
  LocalStorageSave,
  SettingsService,
  type ChessProfile,
  defaultChessProfile,
} from "@starcade/core";
import { LauncherScreen } from "./src/screens/launcher-screen";
import { ChessScreen } from "./src/screens/chess-screen";

export type RootStackParamList = {
  Launcher: undefined;
  Chess: { mode: "ai" | "hotseat" };
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export default function App() {
  const [save] = useState(() => new SaveController(new LocalStorageSave()));
  const [settings] = useState(() => {
    const s = new SettingsService();
    s.load();
    return s;
  });
  const [profile, setProfile] = useState<ChessProfile>(defaultChessProfile());

  useEffect(() => {
    save.load().then((result) => setProfile(result.profile));
    return save.onChange(setProfile);
  }, [save]);

  return (
    <NavigationContainer>
      <StatusBar style="light" />
      <Stack.Navigator
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: "#130E24" },
          animation: "slide_from_right",
        }}
      >
        <Stack.Screen name="Launcher">
          {(props) => <LauncherScreen {...props} profile={profile} />}
        </Stack.Screen>
        <Stack.Screen name="Chess">
          {(props) => (
            <ChessScreen
              {...props}
              save={save}
              settings={settings}
            />
          )}
        </Stack.Screen>
      </Stack.Navigator>
    </NavigationContainer>
  );
}
