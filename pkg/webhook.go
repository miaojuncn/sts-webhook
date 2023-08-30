package pkg

import (
	"context"
	"fmt"

	appsv1 "k8s.io/api/apps/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
)

var (
	webhookLog = log.Log.WithName("webhook")
)

// +kubebuilder:webhook:path=/mutate-apps-v1-statefulset,mutating=true,failurePolicy=fail,groups="apps",resources=statefulsets,verbs=create;update,versions=v1,name=mj

// StatefulSetVolume snapshot volume
type StatefulSetVolume struct {
	Client client.Client
}

func (s *StatefulSetVolume) Default(ctx context.Context, obj runtime.Object) error {
	sts, ok := obj.(*appsv1.StatefulSet)
	if !ok {
		return fmt.Errorf("expected a StatefulSet but got a %T", obj)
	}

	name := sts.Name
	namespace := sts.Namespace
	volumeTemplate := sts.Spec.VolumeClaimTemplates
	fmt.Printf("volumeTemplate: %v\n", volumeTemplate)
	webhookLog.Info("received %s StatefulSet events in %s namespace", name, namespace)

	if err := s.Client.Get(ctx, types.NamespacedName{Namespace: namespace, Name: name}, sts); err != nil {
		if errors.IsNotFound(err) {
			return nil
		}
		webhookLog.Error(err, "failed to get %s StatefulSet", name)
		return err
	}

	return nil
}
